# Setting And Changing Variables

A variable is where a game keeps what it knows: score, health, ammo, a name, a flag, a meter that
fills while a button is held. This guide covers the builtin rows that hold and nudge a value - the
plain arithmetic set, the eased and guarded forms, the fallbacks that make a loaded value safe to
store, and the throwaway locals and constants that live for one event only.

This vocabulary is builtin. Each row compiles to the exact GDScript line it names, so a sheet variable
is a real member of the emitted script and a local really is a `var` inside the handler.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Score, health, gold, ammo** - the numbers every game counts.
- **Flags** - paused, unlocked, has_key - flipped with one row instead of two branches.
- **Meters that fill while a button is held**, and clamp themselves at the top.
- **Camera and UI values that should glide** rather than snap, at any frame rate.
- **Cycling indexes** that must stay in range as they wrap.
- **Loaded values** from a save file or JSON, which might be missing or the wrong kind.
- **Player names** that fall back to "Player" when the field was left blank.
- **Throwaway values inside one event** - a direction, a target, an intermediate result.
- **Tuning constants** kept next to the rows that use them.
- **Picking between two values** in a single cell, with no extra event.

## Core concepts

- **A sheet variable is a member of the script.** Set value writes it, Get Variable reads it, and it
  survives between events and between frames. A LOCAL variable, by contrast, exists only for the body
  of the event that declared it.
- **The compound forms are not sugar.** **Add to** emits `+=`, **Multiply Variable** emits `*=`.
  They exist so that changing a value relative to itself stays a row rather than falling back to a raw
  GDScript block.
- **Move Toward (smooth) is frame-rate independent.** It uses the exponential damping form, so the same
  **Speed** covers the same ground per second at 30 fps and at 144. The naive `lerp(a, b, 0.1)` written
  straight into a per-frame event does not.
- **Charge Toward is tuned in the number a designer thinks in.** You say "reach the maximum in this
  many seconds", not "add this much per frame", and the clamp at the top is baked in.
- **The Or family answers "and if it is not there?"** A value that was loaded rather than typed might
  be missing, null, or the wrong kind. **Number Or**, **Text Or**, **List Or**, **Record Or** and
  **Value Or** hand back the value when it really is that kind of thing, and your own default
  otherwise, so one row replaces a guard row plus a conversion.
- **A zero is not missing.** **Number Or** keeps `0`, and **Value Or** keeps `0` and `""` alike. Only
  the emptiness of a text, a list or a record counts as nothing.
- **Locals come in three shapes for a reason.** `var x = 1`, `var x: float = 1.0` and `var x := 1.0`
  are three different GDScript lines, and each has its own action so that reopening a hand-written
  script lifts the line back to the row that wrote it, byte for byte.

## Reference tables

On the canvas these read as sentences, with the parameter values drawn in bold:

- Set variable **score** to **0**
- Add **1** to **score**
- Move **camera_x** toward **player.x** at speed **8.0**
- **loaded_name** as text, or **"Player"**

### Variables - the arithmetic set

| Name | What it does | Ships as |
|------|--------------|----------|
| Set value | Sets a **Variable** to a **Value** you give. | `{var_name} = {value}` |
| Add to | Adds an **Amount** to a variable - score, health. | `{var_name} += {amount}` |
| Subtract from | Subtracts an **Amount** - spending money, taking damage. | `{var_name} -= {amount}` |
| Multiply Variable | Multiplies a variable by a **Factor**. | `{var_name} *= {amount}` |
| Divide Variable | Divides a variable by a **Divisor**. | `{var_name} /= {amount}` |
| Modulo Variable | Replaces a variable with its remainder over a **Divisor**, for cycling an index. | `{var_name} %= {amount}` |
| Get Variable | Reads the current value of a named **Variable**. | `{var_name}` |

### Variables - the eased and guarded forms

| Name | What it does | Ships as |
|------|--------------|----------|
| Move Toward (smooth) | Eases a **Variable** toward a **Toward** value at a **Speed**, frame-rate independently. Works on numbers, Vector2/Vector3 and Colors alike. | `{var_name} = lerp({var_name}, {target}, 1.0 - exp(-maxf({speed}, 0.0) * get_process_delta_time()))` |
| Charge Toward | Fills a **Variable** while the event runs, reaching **Up To** after **Over Seconds**, clamped at the top. | `{var_name} = minf({var_name} + (maxf({maximum}, 0.0) / maxf({seconds}, 0.001)) * get_process_delta_time(), maxf({maximum}, 0.0))` |
| Toggle boolean | Flips a true/false **Variable** to its opposite. | `{var_name} = not {var_name}` |
| Toggle Boolean | The Helpers twin of Toggle boolean, for a boolean variable. | `{var_name} = not {var_name}` |
| Value If (one of two values) | Picks **If true** or **If false** depending on a **Condition**, all in one cell. | `({true_value} if {condition} else {false_value})` |

### Variables - the missing-value fallbacks

| Name | What it does | Ships as |
|------|--------------|----------|
| Number Or | The **Value** when it really is a number, or **Or** when it is missing, null, text, or anything else. A zero is kept. | `({value} if typeof({value}) in [TYPE_INT, TYPE_FLOAT] else {fallback})` |
| Text Or | The **Value** when it really is text with something in it, or **Or** when it is missing, null, blank, or another kind. | `({value} if (typeof({value}) == TYPE_STRING and {value}) else {fallback})` |
| List Or | The **Value** when it really is a list with items in it, or **Or** otherwise. A Split Text result counts as a list. | `({value} if ((typeof({value}) == TYPE_ARRAY or typeof({value}) >= TYPE_PACKED_BYTE_ARRAY) and {value}) else {fallback})` |
| Record Or | The **Value** when it really is a record (a dictionary) with keys in it, or **Or** otherwise. | `({value} if (typeof({value}) == TYPE_DICTIONARY and {value}) else {fallback})` |
| Value Or | The **Value** unless it is null, in which case **Or**. Guards nothing else - a zero, a blank text and an empty list are all real values here. | `({value} if {value} != null else {fallback})` |

### Helpers - locals and constants, scoped to one event

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Local Variable | Creates a temporary **Name** holding a **Value**, used only within this event. | `var {name} = {value}` |
| Set Local Variable (typed) | The same with a fixed **Type** (float, int, bool, String, Vector2, Vector3). | `var {name}: {var_type} = {value}` |
| Set Local Variable (inferred) | The same, with the type inferred from the **Value**. | `var {name} := {value}` |
| Set Local Constant | Creates a named constant used only within this event. | `const {name} = {value}` |
| Set Local Constant (typed) | The same with a fixed **Type** (int, float, bool, String, Vector2, Vector3). | `const {name}: {const_type} = {value}` |
| Set Local Constant (inferred) | The same, with the type inferred from the **Value**. | `const {name} := {value}` |

## Use cases

**1. Start a run with clean numbers.**

```
On Ready
  -> Set value   score = 0
  -> Set value   health = 100
  -> Set value   has_key = false
```

**2. Count a pickup.**

```
On Body Entered ( body )
  -> Add to   score += 10
```

```gdscript
score += 10
```

**3. Take damage without writing the subtraction by hand.**

```
On hit ( amount )
  -> Subtract from   health -= amount
```

**4. A double-score power-up, and its end.**

```
On powerup collected
  -> Multiply Variable   score_multiplier *= 2

On powerup expired
  -> Divide Variable   score_multiplier /= 2
```

**5. Cycle a menu index that must stay in range.**

```
On Action Just Pressed  "ui_down"
  -> Add to   menu_index += 1
  -> Modulo Variable   menu_index %= 4
```

**Modulo Variable** is the row that stops the index running off the end. For a range that does not
start at zero, **Wrap (int)** is the expression to reach for instead.

**6. Flip a flag with one row instead of two branches.**

```
On Action Just Pressed  "pause"
  -> Toggle   paused
  -> Set Game Paused   paused
```

**7. A camera value that glides instead of snapping.**

```
Every Frame
  -> Move Toward (smooth)   camera_x toward $Player.global_position.x at speed 8.0
```

Around 8 feels like a firm camera follow. Because it uses the exponential form, the follow feels the
same on a slow machine and a fast one.

**8. Fade a colour, with the same action.**

```
Every Frame
  -> Move Toward (smooth)   flash_tint toward Color(1, 1, 1, 1) at speed 6.0
  -> Set Color Tint   flash_tint
```

**Move Toward (smooth)** is generic: numbers, Vector2, Vector3 and Color all work, because `lerp` does.

**9. A hold-to-charge shot.**

```
Every Frame
  Condition: Is Action Pressed   "fire"
    -> Charge Toward   power up to 100.0 over 1.5 seconds

On Action Just Released  "fire"
  -> Call Function   fire_with(power)
  -> Set value   power = 0
```

The meter clamps itself at 100 however long the button is held, so the release event just reads the
value.

**10. Pick between two values in one cell.**

```
Every Frame
  -> Set Text   Value If ( "ALIVE", health > 0, "DEAD" )
```

The three parameters are **If true**, **Condition**, **If false**, in that order on the row.

**11. A speed that depends on a flag, with no branch.**

```
Every Physics Tick
  -> Set Velocity X   direction * Value If ( 320.0, sprinting, 180.0 )
```

**12. A loaded score that might not be there.**

```
On Ready
  -> Set value   score = Number Or ( save.get("score", null), 0 )
```

A saved `0` is kept as a real score - only a missing, null or non-numeric value falls through to the
default.

**13. A player name that falls back gracefully.**

```
On Ready
  -> Set value   player_name = Text Or ( save.get("name", null), "Player" )
```

A blank name counts as nothing here, which is exactly the behaviour a name field wants.

**14. A loaded inventory that is safe to loop over.**

```
On Ready
  -> Set value   inventory = List Or ( loaded.get("items", null), [] )

For Each  item  in  inventory
  -> Call Function   add_to_bag(item)
```

Feeding a **For Each** the raw loaded value risks looping over null; feeding it the **List Or** result
never does.

**15. A whole settings block that might be missing.**

```
On Ready
  -> Set value   settings = Record Or ( loaded.get("audio", null), {} )
  -> Set value   music_volume = Number Or ( settings.get("music", null), 0.8 )
```

A missing block reads as defaults all the way down, with no guard rows.

**16. A method that can hand back nothing.**

```
On Ready
  -> Set value   target = Value Or ( Nearest Node In Group("enemies"), null )
```

**Value Or** guards null and nothing else, which is right for a lookup that either finds something or
does not.

**17. A throwaway value used by the rows after it.**

```
Every Physics Tick
  -> Set Local Variable (inferred)   heading := (target.global_position - global_position).normalized()
  -> Set Velocity   heading * 200.0
  -> Move And Slide
```

`heading` exists for this event only. It never becomes a member of the script and never collides with
another event's throwaway value.

**18. A typed throwaway value, when the type matters.**

```
Every Physics Tick
  -> Set Local Variable (typed)   speed : float = 200.0
  -> Set Velocity X   direction * speed
```

Use the typed form when the value will be handed to something that expects a specific type - a `float`
stored into an `int` truncates silently.

**19. A tuning constant next to the rows that use it.**

```
Every Physics Tick
  -> Set Local Constant (typed)   GRAVITY : float = 980.0
  -> Add To Velocity   Vector2(0, GRAVITY * delta)
```

A constant is folded once and cannot be reassigned by a later row, which is what makes it read as a
tuning knob rather than as state.

**20. Read a variable inside another row's cell.**

```
Every Frame
  Condition: Compare variable   health < 25
    -> Set Color Tint   Color(1, 0.4, 0.4, 1)
```

**Get Variable** is the expression form for the times a variable needs to appear inside a cell rather
than as the row's own subject.

### Other use cases

**Combo counters.** Add to on each hit plus Set value back to zero on a miss makes a combo meter from two rows, with Move Toward (smooth) driving the on-screen number so it catches up rather than jumping.

**Difficulty flags from settings.** Number Or over a loaded difficulty value, with a sane default, means a corrupted or hand-edited settings file can never start the game in an unplayable state.

**Cooldown bars.** Charge Toward filling a display variable while a cooldown runs gives a bar that fills at a rate you tuned in seconds, independent of the cooldown's own timing.

**Toggleable debug overlays.** Toggle on a boolean, read by a visibility row, turns any debug view into one keypress with no state machine.

**Wrapping palettes.** Add to then Modulo Variable over a colour list length cycles a theme colour on each press and never runs past the end of the list.

## Tips and common mistakes

- **Divide Variable by zero is still a division by zero.** The action does not guard it. Test the
  divisor first, or use an expression that clamps it.
- **Modulo Variable is integer modulo.** `%=` on a float is a GDScript error. For decimals, use the
  **Float Modulo** expression instead.
- **Move Toward (smooth) and Charge Toward want a per-frame trigger.** Both read
  `get_process_delta_time()`, so they advance a little per call. Under **On Ready** or a signal trigger
  they run once and appear to do nothing.
- **Charge Toward belongs under a while-held condition**, not on the press. The press is a single
  frame; the charge is what happens across the frames after it.
- **The Or family reads its value twice.** The guard re-reads the value expression, so a value that
  CHANGES something each time it is read - a method that consumes, deals, or advances - runs twice per
  row. Keep the value a plain read: a variable, a `.get()`, a field.
- **A zero is not missing.** **Number Or** keeps `0` and **Value Or** keeps `0` and `""`. If you want a
  zero to fall through to a default, that is a comparison, not a fallback.
- **Value Or only guards null.** An empty list or a blank string passes straight through it. Use
  **List Or** or **Text Or** when emptiness should count as missing.
- **The guards are typeof checks on purpose.** They are written as `typeof(x) == TYPE_STRING`, never
  `x is String`, because the analyser refuses to compile an `is` check against a value it already knows
  is another type. The typeof form compiles against anything and simply lands on the fallback at
  runtime, so pointing a row at the wrong variable is a wrong answer instead of a build break.
- **A local is scoped to its event.** Declaring `temp` in one event and reading it in another does not
  work; that is what a sheet variable is for.
- **Do not declare the same local twice in one event.** Two **Set Local Variable** rows with the same
  **Name** in one body is a redeclaration error. The second one should be a **Set value** row, or a
  different name.
- **A constant must be constant.** **Set Local Constant** emits `const`, so its **Value** has to be
  computable at compile time. A node lookup or a `delta` in there will not compile - use a local
  variable instead.
- **Toggle boolean and Toggle Boolean emit the same line.** The two really do ship under names that
  differ only in one capital letter. They exist in two places because one belongs to the
  Variables vocabulary and one to the generic Helpers escape hatch. Pick either; the output is
  identical.
