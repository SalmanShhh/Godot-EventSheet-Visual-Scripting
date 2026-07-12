# ComboBox

ComboBox is a headless input-sequence detector you drop into any Godot EventSheets project. It ships as the **`ComboBox` autoload singleton**, so it is available from every sheet with zero wiring: just type `ComboBox:` in the action picker and the whole vocabulary is there. It keeps a rolling buffer of named input **tokens**, matches that buffer against the **sequences** you register after every input, and fires **On Combo Matched** the moment a sequence completes. The key idea: **it detects, you react.** ComboBox reads no hardware input itself. You call **Press Input** with a token string from your own events - a key, a gamepad button, a swipe, a gesture recognizer, a network packet - so it works with any input source, and all the payoff (hit sparks, combo counters, input displays) is your work, driven by the triggers. This guide covers the whole pack: the mental model, setup, every Action, Condition, Expression, and Trigger, a stack of concrete use cases, and the traps to avoid.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Fighting-game specials.** A quarter-circle motion like `down, forward, punch` fires a fireball, tolerating the stray neutral inputs a real stick throws in between.
- **Cheat codes.** The classic `up, up, down, down, left, right, left, right, b, a` unlock, with no time pressure so a player can type it at their own pace.
- **Rune-gesture spells.** A drawn gesture recognizer feeds shape tokens (`circle`, `line`, `point`) and a matching spell casts when the pattern completes.
- **Rhythm and timing patterns.** A `tap, tap, hold, tap` beat fill that only counts when the taps land inside a tight window.
- **Combination locks.** A safe dial or keypad that opens on the exact ordered digits, strictly with no wrong inputs mixed in.
- **Quick-time events.** A staggered boss opens a `left, right, left, right` finisher window that must be hit fast.
- **Mash and flurry attacks.** Three quick punches in a row, gated by a short window so a slow triple-tap does not qualify.
- **Context-sensitive movesets.** Ground moves and air moves share button names but only the right set is enabled, switched in batches by tag as the player lands or jumps.
- **Konami-style unlockables.** Any long secret sequence that reveals a hidden mode, a debug menu, or a bonus character.
- **Charge and directional inputs.** A wildcard token matches "any direction, then attack" without registering one combo per direction.
- **Live combo meters.** Partial-match progress drives a fill bar that grows as the player nails each step of a longer string.
- **Boss counters that beat the player.** A boss reaction sharing the player's motion wins the same input through higher priority.

---

## Core concepts

The whole detector is a handful of ideas: **tokens**, the **rolling buffer**, **sequences**, **timing windows**, **wildcards**, **strict vs tolerant** matching, **tags**, **priority**, and **partial matches**.

**Tokens are the words of your input language.** A token is just a string you make up: `"punch"`, `"down"`, `"forward"`, `"b"`, `"3"`, `"circle"`. ComboBox never looks at your keyboard or pad. You decide what a token means and push it in with **Press Input** whenever your own input event fires. Because tokens are plain strings, the exact same detector works for keys, gamepad buttons, touch swipes, drawn gestures, or messages off the wire.

**The rolling buffer is the recent history.** Every **Press Input** appends its token to a buffer, oldest first. The buffer holds only the last **buffer_length** tokens (default `12`); older inputs drop off the front, so stale history can never complete a combo. Each token is stamped with the time it arrived, which is what the timing windows read.

**A sequence is a combo you register.** You call **Register Combo** with a unique `id` and the sequence as a comma-separated token string, for example `"down,forward,punch"`. ComboBox stores it in a registry keyed by id. Registering the same id again replaces it. A combo matches when the newest end of the buffer lines up with the whole sequence.

**Timing windows are per-gap and measured in seconds.** The `timing_window` on **Register Combo** is the seconds allowed between two consecutive inputs of the combo, not the total time for the whole thing. Every pair must land inside the window or the run breaks. The values are Godot seconds (`0.3`), never milliseconds. Three special values: `-1` means "use the global default" (**default_timing**, `0.5` out of the box), and `0` means "no time limit at all" (good for cheat codes and combination locks). ComboBox runs its own clock in the background, so timing just works with no timer wiring on your part, and a partial run that goes quiet past its window fires **On Combo Failed** on its own.

**A `"*"` token is a wildcard.** Put `"*"` anywhere in a sequence and it matches any single input at that spot. `"*,attack"` reads as "any input, then attack", so one combo covers every direction instead of registering four.

**Strict vs interleave-tolerant matching.** By default a combo is tolerant: unrelated inputs sitting between the combo's tokens are skipped, so a stray neutral input does not break a fighting-game motion. Turn on **Set Combo Strict** and the combo's inputs must be adjacent in the buffer with nothing unrelated in between - what a combination lock or a precise flurry wants.

**Tags group combos for batch control.** **Set Combo Tags** attaches comma-separated tags to a combo. Then **Enable Combos By Tag** and **Disable Combos By Tag** flip whole sets at once, so switching from a ground moveset to an air moveset is two calls, not one per move.

**Priority decides who wins when several complete at once, and only one wins per input.** After each input, ComboBox finds every combo that just completed and fires **On Combo Matched** for exactly one of them: the highest **priority** (set with **Set Combo Priority**, default `0`), then the longest sequence, then the first registered. That is deliberate: a two-input sub-combo does not also fire when the longer combo it is part of completes, and a boss reaction can beat the player's move on the same frame.

**Partial matches let you show progress.** Whenever an input advances one or more combos part-way (but does not complete any), **On Partial Progress** fires. Inside it, **Partial Count** tells you how many combos are mid-string, and **Partial Progress** / **Partial Length** for each give you a "3 of 5" you can turn into a fill bar. When a combo that was progressing breaks (a wrong input, or its window elapsed), **On Combo Failed** fires with **Failed Id** and **Fail Index**.

**Three Inspector knobs tune the whole detector.** **buffer_length** (how many recent inputs to remember), **default_timing** (the seconds between inputs for any combo whose own window is `-1`), and **debug_logging** (prints every input, buffer size, and match to the Output panel while you tune). Each has a live equivalent action - **Set Buffer Length** and **Set Default Timing** - for changing it at runtime.

---

## Setup

There is nothing to install per scene and nothing to attach. ComboBox is registered as the **`ComboBox` autoload**, so every sheet can call it. In your action picker, choose the **ComboBox** category; in an expression field, type `ComboBox.` and the expressions autocomplete.

A minimal first example, as event-sheet rows. It registers one combo on ready, presses tokens from your own key events, and reacts when the combo lands:

```
On Ready
  -> ComboBox: Register Combo  "hadouken", "down,forward,punch", 0.3

Keyboard On "down" pressed
  -> ComboBox: Press Input  "down"
Keyboard On "right" pressed
  -> ComboBox: Press Input  "forward"
Keyboard On "z" pressed
  -> ComboBox: Press Input  "punch"

On Combo Matched
  ComboBox.Matched Id() = "hadouken"
    -> Spawn fireball
```

Here each key event pushes its own token, so pressing down, then right, then Z within 0.3 seconds of each step builds the buffer up to `down, forward, punch`, the `hadouken` combo completes, and **On Combo Matched** fires. `Spawn fireball` stands in for whatever your game does - play an animation, instance a projectile, add screenshake. The `ComboBox` calls are the real part.

Because the pack is a live event sheet, you can also open it and extend it directly, but you never have to: the ACEs below cover the whole workflow.

---

## ACE reference

Every name below is exactly what appears in the picker. Parameters are listed in order.

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Register Combo** | `id`, `sequence`, `timing_window` | Registers (or replaces) a combo: a unique id and its sequence as comma-separated tokens (e.g. `"down,forward,punch"`). `timing_window` is the seconds allowed between inputs (`-1` = use the default, `0` = no time limit). Use `"*"` as a token to match any input. |
| **Set Combo Tags** | `id`, `tags` | Tags a registered combo with comma-separated tags, so you can enable or disable it in batches (e.g. `"ground_move"`). |
| **Set Combo Priority** | `id`, `priority` | Sets a combo's priority. When more than one combo completes on the same input, the highest priority wins (ties go to the longest, then to the first registered). |
| **Set Combo Strict** | `id`, `strict` | When strict is on, the combo's inputs must be adjacent in the buffer (no unrelated input between them). Off (the default) tolerates stray inputs in between, like a fighting-game motion. |
| **Set Default Timing** | `seconds` | Sets the default seconds allowed between inputs, used by any combo whose own timing window is `-1`. |
| **Set Buffer Length** | `length` | Sets how many recent inputs to remember. Older inputs drop off, so stale history cannot complete a combo. |
| **Press Input** | `token` | Pushes one input token into the buffer and checks every combo. Call this from your own input events. Fires On Combo Matched / On Partial Progress / On Combo Failed as needed. |
| **Clear Buffer** | (none) | Empties the buffer and resets all partial progress (fires On Buffer Cleared). Call it on a context change so old inputs cannot leak into new combos. |
| **Enable Combo** | `id` | Enables a combo so it takes part in matching. |
| **Disable Combo** | `id` | Disables a combo so it is skipped in matching (its registration is kept). |
| **Enable Combos By Tag** | `tag` | Enables every combo carrying a tag (e.g. all `"air_move"` combos). |
| **Disable Combos By Tag** | `tag` | Disables every combo carrying a tag. |
| **Remove Combo** | `id` | Permanently removes a combo from the registry. |

### Conditions

| Condition | Parameters | What it checks |
| --- | --- | --- |
| **Has Combo** | `id` | Whether a combo id is registered. |
| **Is Combo Enabled** | `id` | Whether a combo is registered and enabled. |
| **Is Buffer Empty** | (none) | Whether the input buffer has no tokens. |
| **Combo Has Tag** | `id`, `tag` | Whether a combo carries a tag. |

### Expressions

| Expression | Parameters | Returns | What it gives you |
| --- | --- | --- | --- |
| **Matched Id** | (none) | String | The id of the combo that just matched (inside On Combo Matched). |
| **Matched Tags** | (none) | String | The matched combo's tags as a comma-separated string (inside On Combo Matched). |
| **Match Time** | (none) | float | The clock time in seconds when the combo matched (inside On Combo Matched). |
| **Failed Id** | (none) | String | The id of the combo that just failed (inside On Combo Failed). |
| **Fail Index** | (none) | int | How many inputs deep the failed combo had reached before it broke (inside On Combo Failed). |
| **Buffer Length** | (none) | int | How many tokens are in the buffer right now. |
| **Buffer Token** | `index` | String | The token at a buffer index (`0` = oldest); `""` if out of range. |
| **Buffer Time** | `index` | float | The clock time in seconds of the token at a buffer index (`0` if out of range). |
| **Cleared Count** | (none) | int | How many tokens were in the buffer when it was last cleared (inside On Buffer Cleared). |
| **Partial Count** | (none) | int | How many combos are part-way matched after the last input (inside On Partial Progress). |
| **Partial Id** | `index` | String | The id of the part-way combo at an index (use with Partial Count to loop). |
| **Partial Progress** | `index` | int | How many inputs of the part-way combo at an index are matched so far. |
| **Partial Length** | `index` | int | The total length of the part-way combo at an index (pair with Partial Progress for a fill bar). |
| **Combo Count** | (none) | int | How many combos are registered. |
| **Combo Id At** | `index` | String | The registered combo id at an index (use with Combo Count to list them). |

### Triggers

| Trigger | When it fires | Read inside it |
| --- | --- | --- |
| **On Combo Matched** | After an input completes a full sequence (one winner per input). | Matched Id, Matched Tags, Match Time. |
| **On Combo Failed** | When a combo that was progressing breaks, or its window elapsed with no further input. | Failed Id, Fail Index. |
| **On Partial Progress** | When an input advances one or more combos part-way without completing any. | Partial Count, Partial Id, Partial Progress, Partial Length. |
| **On Buffer Cleared** | After Clear Buffer empties the buffer. | Cleared Count. |

### Inspector knobs

Select the ComboBox autoload node to see these; each also has a live-set action.

| Knob | Type | Default | What it does |
| --- | --- | --- | --- |
| **buffer_length** | int | `12` | How many recent inputs to remember. Older inputs drop off so stale history cannot complete a combo. (Live: Set Buffer Length.) |
| **default_timing** | float | `0.5` | Default seconds allowed between two inputs of a combo (`0` = no time limit). A combo can override this with its own `timing_window`. (Live: Set Default Timing.) |
| **debug_logging** | bool | `false` | Print every input, buffer state, and match to the Output panel while tuning. |

---

## Use cases

How to read these snippets: a line starting with **On** (or a `Keyboard On ...` line) is a trigger in the left lane, a plain indented line is a condition, and a line starting with **`->`** is an action. `Keyboard On "z" pressed`, `Spawn fireball`, and similar rows stand in for however your own game reads input and shows results.

### 1. A fighting-game special (motion input)

**Scenario:** A quarter-circle-forward punch throws a fireball. Real stick input is messy, so stray neutral inputs between the motion should not break it - the default tolerant matching handles that.

```
On Ready
  -> ComboBox: Register Combo  "hadouken", "down,forward,punch", 0.3

Keyboard On "down" pressed
  -> ComboBox: Press Input  "down"
Keyboard On "right" pressed
  -> ComboBox: Press Input  "forward"
Keyboard On "z" pressed
  -> ComboBox: Press Input  "punch"

On Combo Matched
  ComboBox.Matched Id() = "hadouken"
    -> Spawn fireball
```

Because the combo is not strict, a brief `neutral` between `down` and `forward` is skipped, and the `0.3` window keeps each step snappy.

### 2. The Konami code (long sequence, generous window)

**Scenario:** A long secret unlock the player types at their own pace, with no time pressure at all.

```
On Ready
  -> ComboBox: Register Combo  "konami", "up,up,down,down,left,right,left,right,b,a", 0

Keyboard On "up" pressed
  -> ComboBox: Press Input  "up"
Keyboard On "down" pressed
  -> ComboBox: Press Input  "down"
(and so on for left, right, b, a)

On Combo Matched
  ComboBox.Matched Id() = "konami"
    -> Unlock bonus mode
```

A `timing_window` of `0` means no time limit, so the sequence completes whenever the last `a` lands, however slowly the player types it. The default buffer of `12` comfortably holds this 10-token code.

### 3. A wildcard: any direction then attack

**Scenario:** A dash-attack that should trigger off any direction the player is holding, without registering one combo per direction.

```
On Ready
  -> ComboBox: Register Combo  "dash_attack", "*,attack", 0.25

Keyboard On any direction pressed
  -> ComboBox: Press Input  direction_name
Keyboard On "x" pressed
  -> ComboBox: Press Input  "attack"

On Combo Matched
  ComboBox.Matched Id() = "dash_attack"
    -> Dash forward and swing
```

The `"*"` token matches whatever direction token arrived, so `left, attack`, `right, attack`, or `up, attack` all complete the one combo within the `0.25` window.

### 4. A mash combo (tight window, strict)

**Scenario:** Three quick punches chain into a flurry, but only if the taps are genuinely fast and adjacent - a slow triple-tap should not count.

```
On Ready
  -> ComboBox: Register Combo  "flurry", "punch,punch,punch", 0.15
  -> ComboBox: Set Combo Strict  "flurry", true

Keyboard On "z" pressed
  -> ComboBox: Press Input  "punch"

On Combo Matched
  ComboBox.Matched Id() = "flurry"
    -> Play flurry animation
```

The tight `0.15` window forces real mashing, and **Set Combo Strict** means any other input between the punches breaks the run.

### 5. A rune-gesture spell (Press Input from any source)

**Scenario:** The player draws a shape; a gesture recognizer names it, and drawing the right shapes in order casts a spell. This shows Press Input coming from something other than keys.

```
On Ready
  -> ComboBox: Register Combo  "fireball_rune", "circle,line,point", 0.6

On gesture recognized
  -> ComboBox: Press Input  recognized_shape_name

On Combo Matched
  ComboBox.Matched Id() = "fireball_rune"
    -> Cast fireball
```

ComboBox does not care that the tokens came from a drawing recognizer instead of a keyboard - it only sees the strings you push. The generous `0.6` gap gives the player time to draw each rune.

### 6. A combination lock (strict, no time limit)

**Scenario:** A safe opens on an exact ordered code, with no wrong digits mixed in and no clock ticking.

```
On Ready
  -> ComboBox: Register Combo  "safe", "3,1,4,1,5", 0
  -> ComboBox: Set Combo Strict  "safe", true

On dial digit entered
  -> ComboBox: Press Input  entered_digit

On Combo Matched
  ComboBox.Matched Id() = "safe"
    -> Open the safe
```

`timing_window` `0` removes the clock (the player can take all day), and strict matching means a single wrong digit interrupts the run so the exact code is required.

### 7. Context gating: ground vs air moves

**Scenario:** Ground moves and air moves reuse the same buttons, but only the right set should be live. Tag each set and flip them in batches as the player lands or jumps.

```
On Ready
  -> ComboBox: Register Combo  "ground_slam", "down,down,attack", 0.3
  -> ComboBox: Set Combo Tags  "ground_slam", "ground"
  -> ComboBox: Register Combo  "air_dash", "forward,forward,attack", 0.3
  -> ComboBox: Set Combo Tags  "air_dash", "air"

On landed
  -> ComboBox: Enable Combos By Tag  "ground"
  -> ComboBox: Disable Combos By Tag  "air"

On jumped
  -> ComboBox: Enable Combos By Tag  "air"
  -> ComboBox: Disable Combos By Tag  "ground"
```

Disabled combos keep their registration but are skipped in matching, so switching movesets is two tag calls instead of re-registering anything.

### 8. A progress bar from partial matches

**Scenario:** A combo meter fills as the player nails each step of a longer string, giving live feedback before it completes.

```
On Partial Progress
  For i = 0 to ComboBox.Partial Count() - 1
    ComboBox.Partial Id(i) = "super_combo"
      -> Set fill bar  ComboBox.Partial Progress(i) / ComboBox.Partial Length(i)
```

**On Partial Progress** fires whenever an input advances a combo without completing it. **Partial Progress** over **Partial Length** gives a `0..1` fill (for example `3 / 5`), and **Partial Id** lets you pick out the specific combo you are metering when several are in flight.

### 9. A "combo failed" reset

**Scenario:** When the player breaks a string part-way, flash the meter and tell them how far they got.

```
On Combo Failed
  ComboBox.Failed Id() = "super_combo"
    -> Flash combo meter red
    -> Show text  "Broke at step " + str(ComboBox.Fail Index())
```

**On Combo Failed** fires both when a wrong input breaks a progressing combo and when its timing window elapses with no further input, so a stalled motion resets itself. **Fail Index** is how many inputs deep it reached before breaking.

### 10. Clearing the buffer on a cutscene

**Scenario:** When a cutscene or menu takes over, old inputs should not leak into combos afterward.

```
On cutscene started
  -> ComboBox: Clear Buffer

On Buffer Cleared
  -> Hide combo meter
  -> Show text  "Cleared " + str(ComboBox.Cleared Count()) + " inputs"
```

**Clear Buffer** empties the history and resets every partial, then fires **On Buffer Cleared** so you can tear down any combo UI. **Cleared Count** reports how many tokens were flushed.

### 11. Priority: a boss combo beats a player combo

**Scenario:** A boss can counter the player's signature motion. When both complete on the same input, the boss's reaction should win.

```
On Ready
  -> ComboBox: Register Combo  "player_special", "down,forward,punch", 0.3
  -> ComboBox: Register Combo  "boss_counter", "down,forward,punch", 0.3
  -> ComboBox: Set Combo Priority  "boss_counter", 10

On Combo Matched
  ComboBox.Matched Id() = "boss_counter"
    -> Boss parries and counters
  ComboBox.Matched Id() = "player_special"
    -> Player fireball
```

Because only one combo wins per input, and `boss_counter` has the higher priority, the same `down, forward, punch` fires the boss reaction while the boss is guarding. Drop the boss combo (or disable it) and the player's special wins again.

### 12. Listing every registered combo

**Scenario:** A debug or move-list screen shows all combos currently in the registry.

```
On move list opened
  -> Clear list
  For i = 0 to ComboBox.Combo Count() - 1
    -> Add list item  ComboBox.Combo Id At(i)
```

**Combo Count** and **Combo Id At** walk the registry so you can build a move list, a debug overlay, or a save-file audit without tracking the ids yourself.

### 13. Unlocking a move at runtime

**Scenario:** A special starts locked, unlocks when the player buys it, and can be removed entirely if the save resets.

```
On Ready
  -> ComboBox: Register Combo  "uppercut", "forward,down,forward,punch", 0.3
  -> ComboBox: Disable Combo  "uppercut"

On uppercut purchased
  -> ComboBox: Enable Combo  "uppercut"

On move refunded
  ComboBox: Is Combo Enabled  "uppercut"
    -> ComboBox: Remove Combo  "uppercut"
```

**Disable Combo** keeps the registration but skips it in matching, so the motion does nothing until **Enable Combo** turns it on. **Remove Combo** deletes it outright when you want it gone for good.

### 14. An input display from the raw buffer

**Scenario:** Show the last few inputs on screen, like the input history strip in a fighting game, straight from the buffer.

```
On refresh input display
  ComboBox: Is Buffer Empty
    -> Show text  "(no input)"
  Else
    For i = 0 to ComboBox.Buffer Length() - 1
      -> Add icon for token  ComboBox.Buffer Token(i)
```

**Buffer Length** and **Buffer Token** (with `0` = oldest) read the rolling history directly, and **Is Buffer Empty** guards the empty case. **Buffer Time** gives each token's timestamp if you want to space the icons by how far apart the inputs landed.

### 15. A practice mode that loosens the whole detector

**Scenario:** A training toggle gives new players more time between inputs and a longer memory, then restores tournament rules - and flushes the buffer so a slow practice motion cannot complete under the tight windows.

```
On practice mode enabled
  -> ComboBox: Set Default Timing  1.2
  -> ComboBox: Set Buffer Length  24

On practice mode disabled
  -> ComboBox: Set Default Timing  0.5
  -> ComboBox: Set Buffer Length  12
  -> ComboBox: Clear Buffer
```

Only combos registered with a `timing_window` of `-1` follow **Set Default Timing**, so register the movelist with `-1` and this one toggle retunes every move at once.

### Other use cases

**Fighting-game training dojo.** A dummy replays the exact motion the player must copy, the partial-progress meter fills as each input lands, and On Combo Failed points at the step that broke.

**Morse-code puzzle doors.** Short and long taps become dot and dash tokens, and a strict, no-time-limit sequence opens each vault door on the exact rhythm pattern.

**Dance-machine minigame.** Direction tokens pressed on the beat feed tight timing windows, with partial progress driving a crowd-excitement meter that collapses on a miss.

**Stealth knock codes.** Knocking on safehouse doors pushes knock tokens; the right pattern opens the door, while On Combo Failed alerts the guard inside.

**Wizard duel counterspells.** Both duelists' gestures feed the same detector, and a higher-priority counter combo beats the incoming cast when they complete on the same input.

---

## Tips and common mistakes

- **Press Input is yours to call.** ComboBox reads no hardware. Nothing happens until you call **Press Input** from your own events, and that is the point: wire it to keys, gamepad buttons, touch swipes, a gesture recognizer, or network packets, and the same detector works for all of them.
- **Timing is in seconds, not milliseconds.** A `timing_window` of `0.3` is 300 ms. If your combos feel impossibly tight, you probably typed a millisecond value like `300` where you meant `0.3`.
- **A timing window of `0` means no time limit.** Use `0` for cheat codes and combination locks where the player should not be rushed. Use `-1` to fall back to **default_timing** (`0.5` by default). Any positive number is the real per-gap window in seconds.
- **Token ids are case-sensitive.** `"Punch"` and `"punch"` are different tokens. Register a combo with one casing and press the other and it will never match. Pick a convention (lowercase is easy) and stick to it on both the register and the press side.
- **Register before you press.** A combo only matches once it is in the registry, so run your **Register Combo** rows on ready (or before the fight starts). Pressing tokens into an empty registry just fills the buffer and matches nothing.
- **Clear the buffer on context changes.** Old inputs sit in the buffer until they age out. On a pause, a cutscene, a menu, or a scene swap, call **Clear Buffer** so a stale half-motion cannot complete a combo the moment control returns.
- **One combo wins per input.** When several sequences complete on the same input, exactly one fires **On Combo Matched**: highest **priority**, then longest sequence, then first registered. That is why a two-input sub-combo does not also fire when the longer combo it is part of finishes - and how a boss reaction beats the player's move on the same frame.
- **Strict forbids stray inputs; the default tolerates them.** Leave a combo non-strict (the default) for fighting-game motions, so a neutral or a stray button between the real inputs is skipped. Turn on **Set Combo Strict** for combination locks and precise flurries, where anything unrelated in between must break the run.
- **Partial progress is a separate trigger from a match.** **On Partial Progress** fires for inputs that advance a combo without completing it; **On Combo Matched** fires only on completion. Meter with the first, pay off with the second, and reset the meter on **On Combo Failed**.
- **Read match context inside its trigger.** **Matched Id** / **Matched Tags** / **Match Time** are meaningful inside **On Combo Matched**, **Failed Id** / **Fail Index** inside **On Combo Failed**, and **Cleared Count** inside **On Buffer Cleared**. Read them there rather than later, when the next input may have moved on.
