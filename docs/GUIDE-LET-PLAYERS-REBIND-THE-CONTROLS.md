# Let players rebind the controls

A controls screen is four events. Not a system, not a framework - four events, one action per row, on
the Keyboard and Gamepad objects where every other key-and-button sentence already lives.

This guide builds the whole thing: a button per control that waits for the next key, binds it, and
shows what it is now; a Reset button; a deadzone slider for the sticks; and the two rows that make a
remap survive the player closing the game.

## What you need first

Every control you want rebindable has to be a **named action in the Input Map** - `jump`, `fire`,
`move left`. That is Godot's project-wide list of controls, and the sheet reads it: open any script
as a sheet and the Object bar's **INPUT** section lists every control the file names, with what each
one is bound to (`jump  Space · A button · Up`). An action a row names that the Input Map does not
have wears a ⚠ there, and the Doctor reports it with the one-line fix.

Add a missing one in **Project ▸ Project Settings ▸ Input Map**.

## 1. The rebind button

One event per control. Drop a Button in the scene, then:

| Condition | Actions |
| --- | --- |
| **Rebind Jump** ▸ On clicked | **Keyboard** ▸ ⏳ Wait for the next key or button **into ev** |
| | **Keyboard** ▸ Clear the bindings of **jump** |
| | **Keyboard** ▸ Bind **jump** to **ev** |
| | **Jump Label** ▸ Set text to **name of ev** |

Read it top to bottom and it is the story: the player clicks, the game waits, the old binding goes,
the new one lands, the label says what it is now.

- **Wait for the next key or button** pauses this event (and only this event) until the player
  presses anything at all - a key, a mouse button, a gamepad button. What they pressed is remembered
  under the name you gave it, `ev`.
- **Clear the bindings of** is what makes the new key the *only* one. Leave it out and the player
  ends up with two keys for jump, which is a real thing some games want and most do not.
- **name of ev** is the readable label - `Space`, `A button`, `Left mouse button`.

The actions live on the object whose bindings they touch: **Keyboard** for keys and mouse buttons,
**Gamepad** for buttons and axes. A control bound to both shows on both.

## 2. The Reset button

| Condition | Actions |
| --- | --- |
| **Reset** ▸ On clicked | **Keyboard** ▸ Reset all bindings to the project's |

One action. It throws away every rebind the player made this session and puts the Input Map back
exactly as you set it in Project Settings. Redraw your labels afterwards.

## 3. The deadzone slider

Sticks drift. A worn controller reports a small push when nothing is touching it, and a game that
believes it walks the player into a wall while the pad sits on the table. The deadzone is how much
travel to ignore.

| Condition | Actions |
| --- | --- |
| **Deadzone Slider** ▸ On value changed **v** | **Gamepad** ▸ Set deadzone of **steer** to **v** |

Each control has its own deadzone in the Input Map, shown in the sheet as a percent, the same way
the Gamepad object shows its Analog deadzone. 20% is a sensible default; a twitchy shooter wants
less, a worn pad wants more.

## 4. Making it survive a restart

This is the step every first controls screen forgets, and nothing complains: the player carefully
remaps eight controls, quits, comes back, and every one of them is gone.

Two rows fix it.

| Condition | Actions |
| --- | --- |
| **Rebind Jump** ▸ On clicked | ... the four rows from step 1 ... |
| | **Keyboard** ▸ Save bindings |

| Condition | Actions |
| --- | --- |
| **Game** ▸ On created | **Keyboard** ▸ Load bindings |

**Save bindings** writes every control's bindings to a plain settings file under `user://` - the same
kind of file Remember Between Runs uses, readable and deletable by hand. **Load bindings** puts them
back. On a first run there is no file yet, so Load does nothing and the player gets the project's own
bindings, which is exactly right.

The Doctor watches this one for you: a script that changes bindings at runtime and never saves them
gets the note *"every remap is lost when the game closes"*.

## 5. Showing the current bindings

Two ways, depending on how much you want to build.

- **One label per control**, set from **name of ev** at the moment you bind it (step 1). Simplest,
  and it is what the four rows above already do.
- **A row per control, built from the Input Map itself.** The **All Input Actions** expression hands
  you every control's name; loop it and use **binding of {action} as text** for each. That way adding
  a control in Project Settings adds a row to the screen with no sheet change at all.

## The whole thing, as the sheet reads it

```
➜ Rebind Jump  On clicked        Keyboard ▸ ⏳ Wait for the next key or button   into ev
                                 Keyboard ▸ Clear the bindings of jump
                                 Keyboard ▸ Bind jump to ev
                                 Jump Label ▸ Set text to name of ev
                                 Keyboard ▸ Save bindings

➜ Reset  On clicked              Keyboard ▸ Reset all bindings to the project's

➜ Deadzone Slider  On value changed  v
                                 Gamepad ▸ Set deadzone of steer to v

➜ Game  On created               Keyboard ▸ Load bindings
```

## Other use cases

- **A "press any key to start" screen.** The same Wait for the next key or button, with nothing bound
  afterwards - you only wanted to know that they pressed something.
- **Per-player controls in local multiplayer.** Name the actions `p2_jump` / `jump_2` and the sheet
  reads them as *jump on gamepad 1*, grouping them under that pad in the Object bar; rebind them with
  the exact same four rows.
- **Control presets.** Save bindings to two different files and load whichever the player picked -
  "Southpaw", "Default", "Lefty".
- **A conflict warning.** Before Bind, use **Has action** plus **binding of {action} as text** across
  the other controls to spot a key already in use, and colour the row instead of silently double-
  binding it.
- **Showing the right glyphs.** **Has gamepads** decides whether the hint says "Space" or "A button",
  and **name of gamepad 0** tells you which family of glyphs to draw.
