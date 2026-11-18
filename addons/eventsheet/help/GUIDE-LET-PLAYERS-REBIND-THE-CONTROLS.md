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
| **Rebind Jump** ▸ On clicked | **Keyboard** ▸ ⏳ Wait for the next key or button press **into ev** |
| | **Keyboard** ▸ Clear the bindings of **jump** |
| | **Keyboard** ▸ Bind **jump** to **ev** |
| | **Jump Label** ▸ Set text to **name of ev** |

Read it top to bottom and it is the story: the player clicks, the game waits, the old binding goes,
the new one lands, the label says what it is now.

- **Wait for the next key or button press** pauses this event (and only this event) until the player
  presses a key, a mouse button or a gamepad button. Mouse movement and letting go do not wake it, and the press is marked handled so the Rebind button that was clicked is not pressed again by the same Space or pad A. What they pressed is remembered
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
| **Game** ▸ On enter tree | **Keyboard** ▸ Load bindings |

**Save bindings** writes every control's bindings to `user://bindings.cfg` - a plain settings file, the same
kind of file a variable's Save choice uses, readable and deletable by hand. **Load bindings** puts them
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
➜ Rebind Jump  On clicked        Keyboard ▸ ⏳ Wait for the next key or button press   into ev
                                 Keyboard ▸ Clear the bindings of jump
                                 Keyboard ▸ Bind jump to ev
                                 Jump Label ▸ Set text to name of ev
                                 Keyboard ▸ Save bindings

➜ Reset  On clicked              Keyboard ▸ Reset all bindings to the project's

➜ Deadzone Slider  On value changed  v
                                 Gamepad ▸ Set deadzone of steer to v

➜ Game  On enter tree               Keyboard ▸ Load bindings
```

## The ready-made way

Everything above is the by-hand version, one row per idea, and it is the right one when a game has a
control or two to rebind. For a whole controls screen the **Game Settings** pack already has the rows, and
the **Input Rebind** showcase (`demo/showcase/input_rebind/`) is that screen built from them. In your own
project the pack is the `Settings` autoload, so its rows are written `Settings.`; in the showcase it is a
child node of the same name, so they read `$Settings.`.

| Condition | Actions |
| --- | --- |
| **Game** ▸ On ready | **Settings** ▸ Load Bindings |
| | **Settings** ▸ Controls Page From The Input Map **on Controls** |

**Controls Page From The Input Map** fills a container with one row per control in your Input Map: its name,
a keyboard button, a pad button and a Reset. Press a button and the pack listens for the next press. A
control added in Project Settings appears on its own, and the keyboard and pad columns are separate so
rebinding one never costs the other.

The pack answers what happens next with triggers, so each answer is an ordinary event:

| Condition | Actions |
| --- | --- |
| **Settings** ▸ On Binding Changed **action** | **Settings** ▸ Save Bindings |
| **Settings** ▸ On Binding Conflict **action, taken_by** | show a panel that says the key is taken; Swap, Take it anyway and Pick another key are three buttons |
| **Swap button** pressed | **Settings** ▸ Swap The Binding |
| **Take button** pressed | **Settings** ▸ Take The Binding Anyway |
| **Pick another button** pressed | **Settings** ▸ Pick Another Key |
| **Settings** ▸ On Binding Cancelled **action** | hide the panel; the old key stays |

- **Swap The Binding** trades the two controls' keys, so nobody is left without one. **Take The Binding Anyway**
  gives the key to the control being rebound and leaves the other without it (it turns up in *Unbound
  Actions*). **Pick Another Key** forgets the press and goes on listening.
- **Escape cancels.** While a row is listening, the key your `ui_cancel` action is bound to stops the
  listening and fires **On Binding Cancelled**; that key cannot itself be bound while listening. A left
  click is captured like any other mouse button, except one that lands on a button, so the player can still
  press Swap or another button; a click anywhere else is bound. A pad's B button
  is a normal binding, so a pad can be rebound too.
- The pack catches the press before any button sees it and marks it handled, so Space or a pad's A does not
  press the button that started the listening a second time.
- **Reset One Binding** and **Reset Every Binding** go back to what Project Settings says.

**The two Save Bindings rows write different files.** The Keyboard object's **Save bindings** keeps every
control in `user://bindings.cfg`; **Settings ▸ Save Bindings** keeps them in `user://settings.cfg` under
`[bindings]`, beside the options. Use one pair or the other, never half of each: whichever pair you save with
is the pair that must load.

## Joining an existing project

- **Controls already in Project Settings ▸ Input Map are read as they are.** The controls page lists every
  control that does not start with `ui_`, and a reset goes back to the values in Project Settings. The
  plugin never writes `project.godot`; the only files it writes are under `user://`.
- **A rebind your own scripts already do** (`InputMap.action_erase_events(...)`, `action_add_event(...)`)
  reads on a sheet as *Clear the bindings of* and *Bind ... to*, because the Keyboard rows are those same
  lines. The file round-trips byte for byte, and nothing is rewritten unless you edit a row.
- **A teammate's own settings file.** If your project already keeps `user://settings.cfg`, the Game Settings
  pack loads the file first and rewrites only its own `[settings]` and `[bindings]` sections, so another
  section survives. Code that writes a brand-new ConfigFile to that path without loading it first would
  wipe them. Point the pack somewhere else with its `settings_file` property: set it in the Inspector when the
  node lives in a scene, or in code before **Load All Settings** when it is an autoload (a bare script added
  as an autoload has no Inspector).
- **What a teammate reads without the plugin:** a `[bindings]` section where each key is a control name and
  each value is the list of its InputEvents, ordinary Godot ConfigFile data that `ConfigFile.load` reads and
  `InputMap.action_add_event` accepts.
- **A global already named `Settings`.** The rows write `Settings.`, so a project whose own global has that
  name gets a quiet note from the Doctor, and the answer is to give your own global another name.

## Other use cases

- **A "press any key to start" screen.** The same Wait for the next key or button press, with nothing bound
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
