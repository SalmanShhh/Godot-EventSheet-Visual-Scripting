# Reading Keyboard, Mouse and Gamepad

This is the **device** vocabulary: verbs that ask a physical device what it is doing right now, without
going through a named input action. "Is the W key down", "where is the pointer", "how far is the right
stick pushed", "did a finger just touch the screen", "buzz the phone".

It is the layer BELOW named actions. If you are building movement, a jump button, or a rebinding screen,
you want named actions instead - see the sibling guide **Setting Up And Rebinding Controls**. Reach for
this guide when the device itself is the subject: a debug key, an FPS mouse-look, a "press any key"
splash, controller-glyph switching, a custom cursor, rumble.

Every verb here compiles to plain Godot (`Input`, `DisplayServer`, `OS`) with zero plugin references.

The **Controls** vocabulary sits alongside it and covers everything around a device rather than the
device's raw state: sticks and triggers on the Gamepad object's own -100 to 100 and 0 to 100 scales
(**Compare Axis**, **Axis Of Gamepad**, **Button Of Gamepad**), gamepads by number
(**On Gamepad Button Pressed** with the device index read as the gamepad number, **Has Gamepads**,
**Vibrate Gamepad For**), fingers and gestures (**On Drag**, **On Pinch**, **On Pan**,
**On Double-Click** with their payloads), a whole controls screen (**Wait For The Next Key Or
Button**, **Clear The Bindings Of**, **Bind Control To**, **Reset All Bindings**, **Set Deadzone
Of**, **Save Bindings** / **Load Bindings** - the guide *Let Players Rebind the Controls* strings
them together), simulated input (**Simulate Control Pressed** / **Released**, **Simulate Input**,
**Stop This Input Here**), the pointer (**Request Pointer Lock**, **Set Cursor Visible** /
**Invisible**, **Keep Cursor Inside The Window**, **Move Cursor To**) and the four handheld sensors
(**Acceleration**, **Gravity Direction**, **Rotation Rate**, **Magnetic Field**, and
**Compare Acceleration** for tilt - all of which report 0 on desktop).

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **FPS mouse-look** - Capture Mouse, then read Mouse Move Delta (event) inside an On Input event.
- **Debug and cheat keys** that must never appear in the player's rebinding screen.
- **Press-any-key splash screens** - Anything Is Pressed is one cell.
- **Controller-glyph switching** - Gamepad Count and Gamepad Name decide which button art to show.
- **Local multiplayer joins** - each player is a device index.
- **Custom cursors** - a crosshair in play, the system arrow in menus.
- **Click-to-select in 3D**, using Mouse Ray Origin (3D) and Mouse Ray Direction (3D).
- **Wheel-driven zoom and weapon switching**, straight off the wheel events.
- **Touch controls** on phones and tablets, gated by Touchscreen Available.
- **Rumble and haptics** - a heavy hit on the gamepad, a short buzz on a phone.

## Core concepts

- **Polling versus events.** Most conditions here POLL: they answer "is it down right now" every time the
  event is checked (Key Is Down, Mouse Button Is Down, Gamepad Button Is Down). The verbs whose names end
  in **(event)** are different: they read the in-scope `event` and are only valid inside an **On Input**
  event. Dropping On Key Pressed (event) into a plain every-tick event will not compile, because there is
  no `event` there.
- **Keys are PHYSICAL.** Key Is Down, On Key Pressed (event) and On Key Released (event) all compare a
  *physical* keycode, so the key in the same place on an AZERTY keyboard behaves like the QWERTY one. That
  is what you want for WASD and what you do NOT want for "the key labelled Q".
- **Key parameters are captured, not typed.** The `key` parameter uses the press-a-key capture editor: you
  press the key and the row fills in `KEY_W` for you. It still stores a constant, so `KEY_SPACE` typed by
  hand works too.
- **Three mouse positions, three coordinate spaces.** Mouse Position (world) is where the pointer sits in
  the level, Mouse Position (screen) is pixels inside the window, and Mouse Position (local) is relative
  to the node the row lives on. Mixing them up is the single most common mouse bug.
- **Mouse mode is one global switch.** Capture Mouse and Release Mouse are the readable pair; Set Mouse
  Mode is the same switch with all four options (visible, hidden, captured, confined). Mouse Is Captured
  reads it back.
- **Devices are numbered.** Every gamepad verb takes a device index, and `0` is the first controller.
  Gamepad Count tells you how many are plugged in.
- **Node-scoped verbs need the right host.** Mouse Position (world) and Mouse Position (local) are scoped
  to `Node2D`; Mouse Ray Origin (3D) and Mouse Ray Direction (3D) are scoped to `Node3D`. On a sheet whose
  host is not that type, the picker will not offer them.

## Verb reference

The "Ships as" column is the exact code the row compiles to. Parameters appear in `{braces}`.

### Keyboard

| Verb | What it does | Ships as |
|------|--------------|----------|
| Key Is Down | True while the given keyboard key is being held down. | `Input.is_physical_key_pressed({key})` |
| On Key Pressed (event) | True the moment a key is pressed, used inside an input event. | `(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == {key})` |
| On Key Released (event) | True the moment a key is released, used inside an input event. | `(event is InputEventKey and not event.pressed and event.physical_keycode == {key})` |
| Anything Is Pressed | True while ANY key, mouse button, or gamepad input is held. | `Input.is_anything_pressed()` |
| Key Name | The readable name of a key ("Space", "Escape"). | `OS.get_keycode_string({key})` |
| Keycode From Name | The keycode for a key name - turn saved binding text back into a key. | `OS.find_keycode_from_string({name})` |

### Mouse

| Verb | What it does | Ships as |
|------|--------------|----------|
| Mouse Button Is Down | True while the given mouse button is being held down. | `Input.is_mouse_button_pressed({button})` |
| On Mouse Button Pressed (event) | True the moment a mouse button goes down, inside an On Input event. | `(event is InputEventMouseButton and event.pressed and event.button_index == {button})` |
| On Mouse Button Released (event) | True the moment a mouse button is let go, inside an On Input event. | `(event is InputEventMouseButton and not event.pressed and event.button_index == {button})` |
| On Mouse Wheel Up (event) | True on a wheel-up tick, inside an On Input event. | `(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP)` |
| On Mouse Wheel Down (event) | True on a wheel-down tick, inside an On Input event. | `(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN)` |
| Mouse Position (world) | The pointer in world coordinates, matching where things sit in the level. | `get_global_mouse_position()` |
| Mouse Position (screen) | The pointer in screen pixels relative to the window. | `get_viewport().get_mouse_position()` |
| Mouse Position (local) | The pointer relative to THIS node's own coordinate space. | `get_local_mouse_position()` |
| Mouse Move Delta (event) | How far the mouse moved THIS event, as a Vector2 in pixels. | `event.relative` |
| Mouse Velocity | How fast the mouse is moving, a Vector2 in pixels per second. | `Input.get_last_mouse_velocity()` |
| Set Mouse Mode | Changes whether the cursor is visible, hidden, or locked to the window. | `Input.mouse_mode = {mode}` |
| Capture Mouse | Locks and hides the pointer so motion feeds your look/aim. | `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` |
| Release Mouse | Makes the pointer visible and free again. | `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` |
| Mouse Is Captured | True while the cursor is locked to the window. | `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED` |
| Move Mouse Pointer | Teleports the pointer to a window position. | `Input.warp_mouse({position})` |
| Set Custom Cursor | Swaps the pointer for your own image. | `Input.set_custom_mouse_cursor(load({image_path}))` |
| Clear Custom Cursor | Restores the system's normal pointer. | `Input.set_custom_mouse_cursor(null)` |
| Mouse Ray Origin (3D) | Where the cursor's picking ray starts in 3D world space. | `get_viewport().get_camera_3d().project_ray_origin(get_viewport().get_mouse_position())` |
| Mouse Ray Direction (3D) | The direction the cursor's picking ray travels in 3D world space. | `get_viewport().get_camera_3d().project_ray_normal(get_viewport().get_mouse_position())` |

Mouse Position (world) and Mouse Position (local) are scoped to `Node2D`; the two Mouse Ray verbs are
scoped to `Node3D` and need an active Camera3D at runtime.

### Gamepad and rumble

| Verb | What it does | Ships as |
|------|--------------|----------|
| Gamepad Button Is Down | True while the given gamepad button is being held down. | `Input.is_joy_button_pressed({device}, {button})` |
| On Gamepad Button Pressed (event) | True the moment a gamepad button goes down, inside an On Input event. | `(event is InputEventJoypadButton and event.pressed and event.button_index == {button})` |
| Gamepad Axis | How far a stick or trigger is pushed, from -1 to 1. | `Input.get_joy_axis({device}, {axis})` |
| Gamepad Is Connected | True when a gamepad at that device slot is plugged in. | `Input.get_connected_joypads().has({device})` |
| Gamepad Count | How many gamepads are plugged in. | `Input.get_connected_joypads().size()` |
| Gamepad Name | The controller's product name ("Xbox Series Controller"). | `Input.get_joy_name({device})` |
| Gamepad Is Recognized | True when the gamepad matches a known mapping. | `Input.is_joy_known({device})` |
| Vibrate Gamepad | Rumbles a connected gamepad at chosen strength for a set duration. | `Input.start_joy_vibration({device}, {weak}, {strong}, {duration})` |
| Stop Gamepad Vibration | Stops a gamepad rumble that is still running. | `Input.stop_joy_vibration({device})` |
| Gamepad Vibration Strength | The current rumble as a Vector2 (weak motor, strong motor). | `Input.get_joy_vibration_strength({device})` |
| Vibrate Phone | Buzzes a handheld device for a moment. Does nothing on desktop. | `Input.vibrate_handheld({duration_ms})` |

The button dropdowns offer `JOY_BUTTON_A`, `B`, `X`, `Y`, the two shoulders, `START`, `BACK` and the four
D-pad directions. The axis dropdown offers `JOY_AXIS_LEFT_X`, `LEFT_Y`, `RIGHT_X`, `RIGHT_Y`,
`TRIGGER_LEFT` and `TRIGGER_RIGHT`.

### Touch

| Verb | What it does | Ships as |
|------|--------------|----------|
| Touchscreen Available | True when the device running the game has a touchscreen. | `DisplayServer.is_touchscreen_available()` |
| On Touch (event) | True the moment a finger touches the screen, inside an input event. | `(event is InputEventScreenTouch and event.pressed)` |
| On Touch Released (event) | True the moment a finger lifts off, inside an input event. | `(event is InputEventScreenTouch and not event.pressed)` |
| Touch Position (event) | The screen position of a touch from the current input event. | `event.position` |

### Raw event helpers

| Verb | What it does | Ships as |
|------|--------------|----------|
| Event Matches Action | True when an input event matches a named action. | `{event}.is_action(&{action})` |
| Event As Text | A readable label for an input event, like "Space" or "Left Mouse Button". | `{event}.as_text()` |

## Use cases

**1. A debug key that never reaches the rebinding screen.** A physical key check needs no InputMap entry.

```
Every tick
  Condition: Key Is Down  KEY_F1
    -> show the debug overlay
```

```gdscript
func _process(_delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_F1):
		$DebugOverlay.visible = true
```

**2. A one-shot key press.** Key Is Down is true every frame the key is held, so use the event form when
you want exactly one trigger per press.

```
On Input
  Condition: On Key Pressed (event)  KEY_ESCAPE
    -> toggle the pause menu
```

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		get_tree().paused = not get_tree().paused
```

Note the `not event.echo` in the shipped template: holding the key down does NOT re-fire it.

**3. Press any key to continue.**

```
Every tick
  Condition: Anything Is Pressed
    -> go to the main menu
```

**4. FPS mouse-look.** Capture the pointer once, then read the per-event delta.

```
On Ready
  -> Capture Mouse

On Input
  Condition: Mouse Is Captured
    -> turn the camera by Mouse Move Delta (event) * sensitivity
```

```gdscript
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.003)
```

**5. Release the pointer for a pause menu, and put it back.**

```
On pause pressed
  -> Release Mouse
  -> show the pause panel

On resume pressed
  -> hide the pause panel
  -> Capture Mouse
```

Gate any mouse-look rows on Mouse Is Captured so the camera does not spin while the menu is open.

**6. Aim a 2D turret at the cursor.** Mouse Position (world) is in the same space as the turret, so no
conversion is needed.

```gdscript
func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())
```

**7. Is the cursor over me?** Mouse Position (local) answers in the node's own space, so a plain
comparison against half the sprite size works.

```
Every tick
  Condition: Mouse Position (local).length() < 32
    -> highlight this icon
```

**8. Drag-select with the button and the world position together.**

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_LEFT
    -> set DragStart = Mouse Position (world)

On Input
  Condition: On Mouse Button Released (event)  MOUSE_BUTTON_LEFT
    -> finish the selection box from DragStart to Mouse Position (world)
```

**9. Wheel zoom.**

```
On Input
  Condition: On Mouse Wheel Up (event)
    -> multiply Camera zoom by 0.9

On Input
  Condition: On Mouse Wheel Down (event)
    -> multiply Camera zoom by 1.1
```

**10. A crosshair in play and the arrow in menus.**

```
On gameplay started
  -> Set Custom Cursor  "res://ui/crosshair.png"

On menu opened
  -> Clear Custom Cursor
```

The path is loaded at runtime, so the image must be a real project resource.

**11. Snap the pointer onto the default menu button after a cutscene.**

```
On cutscene finished
  -> Release Mouse
  -> Move Mouse Pointer  Vector2(640, 400)
```

Move Mouse Pointer works in WINDOW pixels, not world coordinates.

**12. A flick gesture.** Mouse Velocity is already pixels per second, so a threshold is all you need.

```
On Input
  Condition: On Mouse Button Released (event)  MOUSE_BUTTON_LEFT
  Condition: Mouse Velocity.length() > 1200
    -> throw the card in the direction of Mouse Velocity
```

**13. Click-to-select in 3D from the two ray halves.**

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_LEFT
    -> set RayFrom = Mouse Ray Origin (3D)
    -> set RayTo = Mouse Ray Origin (3D) + Mouse Ray Direction (3D) * 1000
```

For the whole job in one row instead, the guide **Raycasting And Overlaps In 3D** has Cast Ray From
Mouse Into (3D).

**14. Analog movement straight off the left stick.** Gamepad Axis returns -1 to 1 per axis.

```gdscript
func _physics_process(delta: float) -> void:
	var move := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	position += move * 300.0 * delta
```

Sticks rest slightly off centre, so ignore small values yourself here - the deadzone that named actions
get for free is not applied to a raw axis read.

**15. An analog trigger.** `JOY_AXIS_TRIGGER_RIGHT` reads 0 to 1, so it can drive a charge meter.

```
Every tick
  -> set ChargeBar value = Gamepad Axis(0, JOY_AXIS_TRIGGER_RIGHT) * 100
```

**16. Show the right button glyphs.**

```
Every tick
  Condition: Gamepad Count > 0
    -> show the gamepad hint art
  Else
    -> show the keyboard hint art
```

Gamepad Name gives the product string when you want to tell an Xbox pad from a PlayStation one, and
Gamepad Is Recognized tells you whether its buttons mean what you expect at all.

**17. Local multiplayer joins.** Every gamepad verb takes a device index, so player 2 is device 1.

```
Every tick
  Condition: Gamepad Is Connected  1
  Condition: Gamepad Button Is Down  device 1, JOY_BUTTON_START
    -> add player 2 to the game
```

**18. Rumble on a heavy hit, and stop it when the hit stops.**

```
On player took heavy damage
  -> Vibrate Gamepad  device 0, weak 0.4, strong 1.0, 0.25 seconds

On game paused
  -> Stop Gamepad Vibration  device 0
```

```gdscript
func _on_heavy_hit() -> void:
	Input.start_joy_vibration(0, 0.4, 1.0, 0.25)
```

Gamepad Vibration Strength reads the current rumble back as a Vector2, so a "rumble intensity" options
slider can show what it is actually doing.

**19. A short haptic buzz on phones.**

```
On button tapped
  Condition: Touchscreen Available
    -> Vibrate Phone  40
```

Vibrate Phone takes MILLISECONDS, and does nothing at all on desktop, so it is safe to leave in.

**20. Touch controls, only where there is a touchscreen.**

```
On Ready
  Condition: Touchscreen Available
    -> show the on-screen joystick

On Input
  Condition: On Touch (event)
    -> spawn a ripple at Touch Position (event)
```

**21. Label a captured event on a rebinding screen.** Event As Text turns the raw event into something a
player can read, and Event Matches Action tells you whether it collides with an existing binding.

```
On Input
  Condition: Event Matches Action  event, "jump"
    -> show "That key is already used for Jump"
  Else
    -> set BindingLabel text = Event As Text(event)
```

### Other use cases

**Idle-attract mode.** Count the seconds since Anything Is Pressed was last true and roll the attract reel when the number passes thirty.

**Photo mode.** Release Mouse, Clear Custom Cursor and Set Mouse Mode to hidden together give a clean screenshot pass with no pointer in the frame.

**Accessibility hold-to-aim.** Read Gamepad Axis on `JOY_AXIS_TRIGGER_LEFT` and treat anything above 0.2 as held, so players who cannot pull a trigger fully still aim.

**Rhythm-game input latency test.** Log Mouse Position (screen) and the frame number inside On Mouse Button Pressed (event) to measure the gap between the beat and the tap.

**Cursor-trail juice.** Feed Mouse Velocity into a particle emitter's direction and amount so the trail thickens as the pointer whips across the screen.

## Tips and common mistakes

- **The (event) verbs only work inside an On Input event.** They read the in-scope `event` variable. In
  any other event that name does not exist and the sheet will not compile. If you need "is it down right
  now" outside an input event, use the polling form: Key Is Down, Mouse Button Is Down, Gamepad Button Is
  Down.
- **Key Is Down is true every frame.** Use On Key Pressed (event) when you want one trigger per press,
  or a named action with On Action Just Pressed (see the Setting Up And Rebinding Controls guide).
- **Physical keycodes ignore the keyboard layout.** That is the right default for position-based controls
  (WASD) and the wrong one if you are matching a printed letter.
- **Do not mix up the three mouse positions.** A turret that jitters, a UI hit test that is always off by
  the camera offset, and a cursor that drifts when the window resizes are all the same bug: world versus
  screen versus local.
- **Mouse mode is global, not per node.** Capture Mouse from one sheet captures for the whole game. Gate
  look rows on Mouse Is Captured rather than assuming.
- **A captured pointer has no position.** While the mouse is captured its screen position stops moving -
  Mouse Move Delta (event) is the only meaningful read. Release Mouse before you expect Mouse Position to
  mean anything again.
- **Set Custom Cursor loads a path at runtime.** A typo produces a null and the cursor silently does not
  change; keep the image inside the project and let the picker's path stand.
- **Raw axes have no deadzone.** `Input.get_joy_axis` reports the stick's actual rest drift. Named actions
  get a deadzone from the InputMap; a raw axis does not, so filter small values yourself.
- **Device 0 is not guaranteed to exist.** Check Gamepad Is Connected before reading a device, or accept
  that the reads answer zero on an empty slot.
- **Vibrate Phone is milliseconds, Vibrate Gamepad is seconds.** `200` and `0.2` are the same length of
  time in those two verbs.
- **Vibration stops on its own.** Vibrate Gamepad already takes a duration, so Stop Gamepad Vibration is
  for cutting a long rumble short (a pause, a death, a scene change), not for routine cleanup.
- **The 3D mouse-ray verbs need an active Camera3D.** With no current camera in the viewport they will
  fail at runtime; they are scoped to `Node3D` hosts for the same reason.
- **Touchscreen Available describes the DEVICE, not the moment.** A laptop with a touchscreen answers true
  even while the player is using a mouse, so use it to decide what to offer, not what is being used.
