# Setting Up And Rebinding Controls

This is the **named action** vocabulary: the layer every game should build its controls on, and the
InputMap verbs that let a player change them while the game is running.

A named action ("jump", "move_left") is a label in Project Settings -> Input Map with one or more keys,
mouse buttons or gamepad buttons behind it. Your sheet asks about the LABEL, and the player gets to decide
what presses it. That is what makes a rebinding screen possible at all, and it is why a raw key check
belongs in a debug row and nowhere else - the sibling guide **Reading Keyboard, Mouse And Gamepad** covers
those.

Everything here compiles to plain Godot (`Input`, `InputMap`) with zero plugin references.

A whole controls screen is written end to end in the guide **Let Players Rebind the Controls**, using the
Controls vocabulary's story version of these verbs: **Wait For The Next Key Or Button**,
**Clear The Bindings Of**, **Bind Control To**, **Key Name**, **Reset All Bindings**, **Has Action**,
**Set Deadzone Of**, and the pair every first rebind screen forgets - **Save Bindings** and
**Load Bindings**, which write and read a plain settings file under `user://` so a remap survives the
player closing the game. The Doctor reports a script that rebinds and never saves.

The Input Map is also readable from the sheet now: open any script and the Object bar's **INPUT** section
lists every control it names with what that control is bound to, and a control the Input Map does not have
wears a ⚠ there and in the Doctor.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Player movement** - one Move Vector cell replaces four key checks and handles analog sticks.
- **Jump, shoot, interact** - On Action Just Pressed fires exactly once per press.
- **Charge-and-release moves** - On Action Just Released closes the loop.
- **A rebinding screen** - Rebind Action To Key is the whole rebinding step in one row.
- **A Reset To Defaults button** - Restore Default Bindings, and nothing else.
- **Controller options** - a deadzone slider per action.
- **Analog input** - Action Strength reads a trigger's pull, not just its yes/no.
- **Runtime-created actions** for mods, mini-games, or per-vehicle control sets.
- **Binding labels in the UI** - Action Binding As Text prints "Space" beside the row.
- **Auditing** - All Input Actions builds the whole rebinding list without hand-writing a row per action.

## Core concepts

- **The action name is the address.** Every verb here takes an action name string. The parameter uses the
  live Input Map picker, so the dropdown lists the actions your project actually has (plus the `ui_*`
  defaults) instead of asking you to remember spellings.
- **Three tenses of "pressed".** Is Action Pressed is true the whole time it is held. On Action Just
  Pressed is true only on the frame it went down. On Action Just Released is true only on the frame it
  came up. Using the first where you meant the second is the classic "my jump fires sixty times" bug.
- **Analog for free.** Action Strength, Input Axis, Move Axis, Move Vector and Input Vector all read the
  underlying analog value, so a stick pushed halfway gives 0.5 and the same rows work on keyboard, where
  it gives 1.
- **Vectors versus axes.** A vector takes four actions and hands back a Vector2 (movement). An axis takes
  two and hands back a single number from -1 to 1 (turning, throttle, a one-dimensional slide).
- **Rebinding is destructive by design.** Every Rebind Action To ... verb CLEARS the action's bindings
  first, then adds exactly one. That is what a rebinding row means. To ADD a second binding without losing
  the first, use Bind Event To Action instead.
- **Runtime rebinds are not saved.** They live in memory. Restore Default Bindings reloads the Input Map
  from Project Settings and throws them all away, and so does restarting the game. Persisting a player's
  choices is your job: store the key names and re-apply them on startup.
- **A rebind needs a captured event.** The clean flow is: show "press a key", listen in an On Input event,
  read the key from the event, and call Rebind Action To Key. Bind Event To Action takes the raw `event`
  when you would rather keep whatever kind of input the player pressed.

## Verb reference

The "Ships as" column is the exact code the row compiles to. Parameters appear in `{braces}`.

### Reading an action

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is Action Pressed | True while the named action is held down, for continuous controls like running. | `Input.is_action_pressed(&{action})` |
| On Action Just Pressed | True only on the frame the action was first pressed, for jumps or single taps. | `Input.is_action_just_pressed(&{action})` |
| On Action Just Released | True only on the frame the action was let go, for charge-and-release moves. | `Input.is_action_just_released(&{action})` |
| Action Strength | How hard an action is held, 0 to 1 (a trigger or stick reads in between). | `Input.get_action_strength({action})` |
| Input Axis | A -1 to 1 value from two opposing actions, like left and right. | `Input.get_axis(&{negative}, &{positive})` |
| Move Axis | A single -1 to 1 axis from two actions (for left/right or up/down). | `Input.get_axis({negative}, {positive})` |
| Read Input Axis Into | Reads a left/right axis into a local variable scoped to this event. | `var {name}: float = Input.get_axis(&{negative}, &{positive})` |
| Move Vector | A ready-made movement direction (a Vector2) from four actions, analog handled. | `Input.get_vector({left}, {right}, {up}, {down})` |
| Input Vector | A movement direction from four input actions, ideal for player movement. | `Input.get_vector(&{left}, &{right}, &{up}, &{down})` |

### Defining actions

| Verb | What it does | Ships as |
|------|--------------|----------|
| Add Input Action | Creates a named action at runtime if it does not already exist. | `if not InputMap.has_action({action}):` / `	InputMap.add_action({action})` |
| Remove Input Action | Removes a runtime input action entirely. | `if InputMap.has_action({action}):` / `	InputMap.erase_action({action})` |
| Has Input Action | True when an input action is registered. | `InputMap.has_action({action})` |
| All Input Actions | Every registered action name, as an Array. | `InputMap.get_actions()` |

### Rebinding

| Verb | What it does | Ships as |
|------|--------------|----------|
| Rebind Action To Key | Clears an action's keys and binds it to a single key. | `InputMap.action_erase_events({action})` then a new `InputEventKey` with `physical_keycode = {physical_keycode}` added back |
| Rebind Action To Mouse Button | Clears an action's bindings and binds it to a mouse button. | `InputMap.action_erase_events({action})` then a new `InputEventMouseButton` with `button_index = {button}` added back |
| Rebind Action To Gamepad Button | Clears an action's bindings and binds it to a gamepad button. | `InputMap.action_erase_events({action})` then a new `InputEventJoypadButton` with `button_index = {button}` added back |
| Bind Event To Action | Binds a new key, button or input to a named action at runtime, without clearing. | `InputMap.action_add_event(&{action}, {event})` |
| Clear Action Bindings | Removes all key and button bindings from a named action. | `InputMap.action_erase_events(&{action})` |
| Restore Default Bindings | Throws away every runtime rebind and reloads the Input Map from Project Settings. | `InputMap.load_from_project_settings()` |
| Set Action Deadzone | How far a stick must move before the action counts. | `InputMap.action_set_deadzone({action}, {deadzone})` |

### Describing bindings

| Verb | What it does | Ships as |
|------|--------------|----------|
| Action Is Bound | True when the action has at least one key or button bound. | `not InputMap.action_get_events(&{action}).is_empty()` |
| Action Binding Count | How many keys or buttons are bound to a named action. | `InputMap.action_get_events(&{action}).size()` |
| Action Binding As Text | The action's first binding as readable text, or "unbound". | `(InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else "unbound")` |

## Use cases

**1. Continuous movement.** Is Action Pressed is the one you want while a key is held.

```
Every tick
  Condition: Is Action Pressed  "move_right"
    -> move the player right by 200 * delta
```

**2. A jump that fires once per press.**

```
Every tick
  Condition: Is On Floor
  Condition: On Action Just Pressed  "jump"
    -> set the player's vertical velocity to -400
```

```gdscript
func _physics_process(delta: float) -> void:
	if is_on_floor() and Input.is_action_just_pressed(&"jump"):
		velocity.y = -400.0
```

**3. A charge-and-release shot.**

```
Every tick
  Condition: Is Action Pressed  "shoot"
    -> add delta to Charge

Every tick
  Condition: On Action Just Released  "shoot"
    -> fire a shot with power Charge
    -> set Charge to 0
```

**4. Eight-way movement in one cell.** Move Vector already normalises and already handles the stick.

```gdscript
func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += move * 250.0 * delta
```

Input Vector is the same expression with StringName action names; either reads identically on the canvas.

**5. A platformer's horizontal axis.**

```gdscript
func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis(&"move_left", &"move_right") * 220.0
	move_and_slide()
```

**6. Name the axis once and reuse it in the event body.** Read Input Axis Into declares a local, so several
actions in the same event share one read.

```
Every tick
  -> Read Input Axis Into  direction, "move_left", "move_right"
  -> set velocity.x = direction * 220
  -> flip the sprite when direction < 0
```

**7. An analog trigger drives the throttle.**

```
Every tick
  -> set Throttle = Action Strength("accelerate")
```

On a keyboard that reads 0 or 1; on a trigger it reads everything in between, and the same row covers both.

**8. Look-around from the right stick, using two axes.**

```
Every tick
  -> turn the camera by Input Axis("look_left", "look_right") * turn_speed * delta
  -> pitch the camera by Input Axis("look_up", "look_down") * turn_speed * delta
```

**9. The rebinding screen: capture, then rebind.**

```
On rebind button pressed
  -> set Rebinding = "jump"
  -> show "Press a key..."

On Input
  Condition: Rebinding is not ""
  Condition: On Key Pressed (event)  (any key)
    -> Rebind Action To Key  Rebinding, event.physical_keycode
    -> set Rebinding to ""
```

Rebind Action To Key erases the action's existing keys first, so the row leaves exactly one binding behind.

**10. Rebind to a mouse button instead.**

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_RIGHT
    -> Rebind Action To Mouse Button  "aim", MOUSE_BUTTON_RIGHT
```

**11. Rebind to a gamepad button.**

```
On Input
  Condition: On Gamepad Button Pressed (event)  JOY_BUTTON_X
    -> Rebind Action To Gamepad Button  "reload", JOY_BUTTON_X
```

**12. Keep BOTH the keyboard and the gamepad binding.** Bind Event To Action adds without clearing.

```
On Ready
  -> Bind Event To Action  "jump", a new gamepad A event
```

Action Binding Count will now read 2 for that action.

**13. The Reset To Defaults button.**

```
On defaults pressed
  -> Restore Default Bindings
  -> refresh the rebinding list
```

This reloads exactly what Project Settings holds, so every runtime rebind and every runtime-added action
binding is gone.

**14. Print each row's current binding.**

```
Every tick
  -> set JumpRowLabel text = "Jump: " + Action Binding As Text("jump")
```

It reads `Jump: Space`, and `Jump: unbound` when the action has nothing behind it.

**15. Build the whole rebinding list from the project.** All Input Actions hands back every registered
action, so the screen never goes stale when you add one.

```
On Ready
  -> For Each  action  in  All Input Actions()
    -> add a rebinding row labelled action with Action Binding As Text(action)
```

**16. Refuse to leave an action unbound.**

```
On close options pressed
  Condition: Action Is Bound  "jump"  (inverted)
    -> show "Jump has no key. Set one before closing."
  Else
    -> close the options panel
```

**17. A stick-drift slider.**

```
On deadzone slider changed
  -> Set Action Deadzone  "move_left", DeadzoneSlider value
  -> Set Action Deadzone  "move_right", DeadzoneSlider value
```

Deadzone is per ACTION, not per stick, so set it on each action the stick feeds.

**18. Actions a mod or mini-game invents at runtime.**

```
On mini-game loaded
  -> Add Input Action  "paddle_up"
  -> Rebind Action To Key  "paddle_up", KEY_W

On mini-game unloaded
  -> Remove Input Action  "paddle_up"
```

Add Input Action already checks for an existing action, so running it twice is harmless.

**19. Guard a row that talks about an optional action.**

```
Every tick
  Condition: Has Input Action  "sprint"
  Condition: Is Action Pressed  "sprint"
    -> set speed to 400
```

Asking Godot about an action that does not exist is an error; Has Input Action is the cheap guard.

**20. Persist the player's bindings yourself.** Save the readable text, restore it through a keycode.

```
On quit pressed
  -> save Action Binding As Text("jump") into settings

On Ready
  -> Rebind Action To Key  "jump", Keycode From Name(saved jump binding)
```

Keycode From Name lives in the device vocabulary (see the Reading Keyboard, Mouse And Gamepad guide) and
turns "Space" back into a key.

**21. Wipe an action before rebuilding it from a saved profile.**

```
On profile loaded
  -> Clear Action Bindings  "jump"
  -> Rebind Action To Key  "jump", saved keycode
```

### Other use cases

**Per-vehicle control sets.** Add Input Action a handful of `heli_*` actions when the player boards the helicopter and Remove Input Action them on exit, so the rebinding screen only shows what is currently flyable.

**Southpaw layout toggle.** One button that rebinds the four look actions to the opposite stick, using three Rebind Action To Gamepad Button rows and no branching.

**Accessibility hold-to-toggle.** Watch On Action Just Pressed on "crouch" and flip a flag instead of using Is Action Pressed, turning every hold into a tap without touching the bindings.

**Tutorial prompts that follow the bindings.** Every hint label reads Action Binding As Text, so the tutorial says "Press E" or "Press Right Bumper" without a single conditional.

**Conflict detection.** Loop All Input Actions and compare each Action Binding As Text against the key the player just captured, so a duplicate binding is caught before it is applied.

## Tips and common mistakes

- **Is Action Pressed versus On Action Just Pressed.** A jump on Is Action Pressed re-fires every frame the
  key is held. A menu that advances on Is Action Pressed skips five entries per press. Use the Just forms
  for anything that should happen once.
- **The action name must exist.** A misspelled action is not a silent no - Godot raises an error. Use the
  dropdown, and guard runtime-created actions with Has Input Action.
- **Rebind Action To ... clears first.** All three Rebind verbs erase the action's existing bindings before
  adding the new one, so a player who rebinds Jump to Space loses the gamepad A binding too. If you want
  keyboard and gamepad on the same action, rebind only the matching kind and add the other with Bind Event
  To Action, or re-add it right after.
- **The Rebind verbs are multi-line actions.** They compile to four lines each, including a temporary
  variable the compiler names for you. Nothing to do about it, but do not expect a rebind row to be a
  single expression you can nest inside another cell.
- **Runtime rebinds do not survive a restart.** Nothing here writes to disk. Save the bindings yourself
  and re-apply them on startup, or the player will redo them every session.
- **Restore Default Bindings is a full reload.** It reloads the entire Input Map from Project Settings, so
  it also removes bindings you added to OTHER actions in the same session, and any action created with Add
  Input Action loses its bindings (the action itself remains).
- **Action Binding As Text only shows the FIRST binding.** An action with a key and a gamepad button
  reports one of them. Use Action Binding Count when you need to know there are more.
- **"unbound" is a real answer, not an error.** Action Binding As Text is written to survive an empty list,
  so a rebinding screen never crashes on a cleared row - but check Action Is Bound before you let the
  player leave.
- **Deadzone belongs to the action.** Setting it on "move_left" does nothing for "move_right"; a stick
  usually needs all four set together.
- **Move Vector and Input Vector are the same call.** Both compile to `Input.get_vector` with four actions;
  Input Vector passes StringName action names and Move Vector passes them plain. Pick one and stay
  consistent within a sheet so the rows read the same.
- **Action Strength is 0 to 1, never negative.** For a direction, use Input Axis or Move Axis, which
  subtract one action's strength from the other's.
- **Do not build gameplay on raw keys.** A raw key check cannot be rebound, does not appear in the options
  screen, and does not work on a controller. Keep those for debug rows.
