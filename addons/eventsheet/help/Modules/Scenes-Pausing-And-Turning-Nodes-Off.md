# Scenes, Pausing And Turning Nodes Off

Three jobs that look like one, and cause more confusion than any other corner of the builtin
vocabulary:

1. **Changing what is on screen** - Go To Scene, Restart Scene, Spawn Scene Instance, Quit Game.
2. **Pausing the whole game** - Set Game Paused, and the per-node question of what "paused" means for
   each node.
3. **Switching one node off** - which is a different question again, and has two honest answers
   depending on whether you mean "stop it running" or "stop this one callback".

The reason pausing and deactivating live together is that in Godot they are the same property.
`process_mode` decides whether a node runs at all AND how it reacts to the game pause. Deactivate Node
sets it to Disabled; Keep Node Running While Paused sets it to Always. Once you see that, the whole
family stops being confusing.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Level flow** - a menu that goes to a level, a level that goes to the next one.
- **Retry** - Restart Scene is the whole death-and-respawn loop for a small game.
- **Spawning** - a scene file dropped into the world at a position, with a rotation and a group.
- **A pause menu that actually works** - the game freezes, the menu keeps running.
- **Cutscenes** - freeze the actors, keep the camera and the dialogue alive.
- **Off-screen rooms** - stop a whole area processing until the player arrives.
- **Performance triage** - turn off just the per-frame work and leave physics and input alone.
- **A confirm-on-quit dialog** - intercept the window's close button and handle it yourself.
- **Ordering fixes** - make the camera update after the thing it follows.
- **Safe access to a fresh spawn** - Node Is Ready guards code that arrives too early.

## Core concepts

- **Changing scene replaces everything.** Go To Scene swaps the whole current scene for another file.
  Nothing survives except autoloads. Restart Scene reloads exactly what is running now.
- **A spawn is a load plus an instantiate plus an add.** Spawn Scene Instance is the one-line form.
  Spawn Scene At also positions it. Spawn Scene (Full) also rotates it and optionally puts it in a
  group. All three add the copy as a child of the node the row runs on.
- **Pausing the game is one flag.** Set Game Paused writes `get_tree().paused`. What that means for
  any given node is decided by that node's own process mode.
- **The five process modes are the whole story.** Inherit follows the parent. Pausable stops when the
  game pauses - the default. When Paused runs ONLY while the game is paused. Always ignores the pause
  entirely. Disabled never runs.
- **"Deactivate" is hide plus disable.** Deactivate Node (2D) and Deactivate Node (3D) set `visible`
  to false AND the process mode to Disabled, for the node and everything under it. Activate Node is
  the exact undo, restoring visibility and setting the mode back to Inherit.
- **"Pause this node" and "deactivate this node" set the same property.** Pause Node also writes
  Disabled - it just does not touch visibility. Pick the verb that says what you meant; a reader of
  the sheet will thank you.
- **Node Is Running answers the WHOLE question.** It compiles to `can_process()`, which already takes
  both the node's mode and the game's pause state into account. Node Is Frozen By The Game Pause is
  the narrower question: the game is paused AND this node is one of the things it froze.
- **Per-callback control is finer than the node.** Set Node Per-Frame Processing, Set Node Physics
  Processing, Set Node Input Handling and Set Node Unhandled Input Handling each switch one callback,
  leaving the others alone. Use them when only one kind of work is the problem.
- **Process order is a number, and lower runs first.** Set Node Process Order and Set Node Physics
  Order are the fix for "my camera lags one frame behind the player".

## Verb reference

### Scene flow

| Verb | What it does | Ships as |
|------|--------------|----------|
| Go To Scene | Switches the game to a different scene file | `get_tree().change_scene_to_file({path})` |
| Restart Scene | Restarts the current scene from scratch | `get_tree().reload_current_scene()` |
| Quit Game | Closes the game and exits to desktop | `get_tree().quit()` |
| Handle Quit Myself | Stops the window's X from quitting instantly | `get_tree().set_auto_accept_quit({mode})` |
| Spawn Scene Instance | Loads a scene file and adds an instance as a child | `add_child(load({path}).instantiate())` |
| Spawn Scene At | Loads a scene and drops a copy at a position | three lines, see below |
| Spawn Scene (Full) | Spawn with position, rotation and an optional group | five lines, see below |
| Set Game Paused | Pauses or resumes the whole game | `get_tree().paused = {paused}` |
| Is Game Paused | True when the game is currently paused | `get_tree().paused` |

**Handle Quit Myself** has a friendly dropdown that inserts the opposite-looking value: "Intercept
(handle it myself)" inserts `false`, and "Allow (quit immediately)" inserts `true`. Set it to
Intercept in a ready handler and the window's close button waits for your own close handler, which
then calls Quit Game explicitly.

**Spawn Scene At** and **Spawn Scene (Full)** bake a per-row unique local so two spawn rows in the
same handler cannot collide:

```gdscript
var __spawn_figure = load("res://enemy.tscn").instantiate()
__spawn_figure.position = Vector2(0, 0)
__spawn_figure.rotation_degrees = 0.0
add_child(__spawn_figure)
if "" != "": __spawn_figure.add_to_group("")
```

### Turning a whole node on and off

| Verb | What it does | Ships as | On |
|------|--------------|----------|----|
| Deactivate Node (2D) | Hides a node and stops it and its children running | `visible = false` then `process_mode = Node.PROCESS_MODE_DISABLED` | CanvasItem |
| Activate Node (2D) | Shows it and starts it running again | `visible = true` then `process_mode = Node.PROCESS_MODE_INHERIT` | CanvasItem |
| Deactivate Node (3D) | The same for a 3D node | `visible = false` then `process_mode = Node.PROCESS_MODE_DISABLED` | Node3D |
| Activate Node (3D) | The same undo for a 3D node | `visible = true` then `process_mode = Node.PROCESS_MODE_INHERIT` | Node3D |
| Node Is Running | True when this node is actually running right now | `can_process()` | Node |
| Set Node Process Mode | Picks any of the five modes directly | `process_mode = {mode}` | Node |
| Node Process Mode | The node's current process mode | `process_mode` | Node |

### Behaviour while the game is paused

| Verb | What it does | Ships as |
|------|--------------|----------|
| Pause Node | Freezes one node and its children, whatever the game is doing | `process_mode = Node.PROCESS_MODE_DISABLED` |
| Unpause Node | Lets the node follow its parent again | `process_mode = Node.PROCESS_MODE_INHERIT` |
| Keep Node Running While Paused | Exempts a node from the game pause | `process_mode = Node.PROCESS_MODE_ALWAYS` |
| Pause Node With The Game | Makes it stop when the game pauses, whatever its parent does | `process_mode = Node.PROCESS_MODE_PAUSABLE` |
| Run Node Only While Paused | Runs ONLY while the game is paused, never otherwise | `process_mode = Node.PROCESS_MODE_WHEN_PAUSED` |
| Node Is Frozen By The Game Pause | True when the game is paused AND this node was frozen | `(get_tree().paused and not can_process())` |

The Set Node Process Mode dropdown offers all five with plain-English labels: Inherit (follow the
parent), Pausable (stops when the game pauses), When Paused (runs ONLY while paused), Always (ignores
the game pause), Disabled (never runs).

### One callback at a time

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Node Per-Frame Processing | Turns just the every-frame work on or off | `set_process({on})` |
| Set Node Physics Processing | Turns just the physics-step work on or off | `set_physics_process({on})` |
| Set Node Input Handling | Turns input handling on or off | `set_process_input({on})` |
| Set Node Unhandled Input Handling | Turns UNHANDLED input handling on or off | `set_process_unhandled_input({on})` |
| Node Is Processing Per Frame | True when the every-frame work is switched on | `is_processing()` |
| Node Is Physics Processing | True when the physics-step work is switched on | `is_physics_processing()` |
| Node Is Handling Input | True when the node still receives input events | `is_processing_input()` |
| Set Node Process Order | Where this node sits in the per-frame order among siblings | `process_priority = {priority}` |
| Set Node Physics Order | The same ordering knob for the physics step | `process_physics_priority = {priority}` |
| Node Is Ready | True once the node has entered the tree and _ready has run | `is_node_ready()` |

## Use cases

**1. Start the game from a menu.**

```gdscript
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_1.tscn")
```

**2. Retry after death.**

```gdscript
func _on_died() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
```

**3. Spawn an enemy at a marker.**

```gdscript
func _on_spawn_timer_timeout() -> void:
	var __spawn_wave = load("res://enemy.tscn").instantiate()
	__spawn_wave.position = $Marker2D.position
	add_child(__spawn_wave)
```

**4. Spawn with a rotation and a tag, in one row.** Spawn Scene (Full) puts the copy straight into the
group your other events already query.

```gdscript
func _on_turret_fired() -> void:
	var __spawn_shot = load("res://bullet.tscn").instantiate()
	__spawn_shot.position = $Muzzle.position
	__spawn_shot.rotation_degrees = rotation_degrees
	add_child(__spawn_shot)
	if "bullets" != "": __spawn_shot.add_to_group("bullets")
```

**5. A pause menu that works.** Three rows: the menu is exempt from the pause, then the pause is set.

```gdscript
func _ready() -> void:
	$PauseMenu.process_mode = Node.PROCESS_MODE_ALWAYS


func _on_pause_pressed() -> void:
	get_tree().paused = true
	$PauseMenu.show()
```

**6. Resume.**

```gdscript
func _on_resume_pressed() -> void:
	get_tree().paused = false
	$PauseMenu.hide()
```

**7. A toggle rather than two buttons.** Is Game Paused is the condition.

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().paused = not get_tree().paused
```

**8. Keep the music playing while paused.**

```gdscript
func _ready() -> void:
	$Music.process_mode = Node.PROCESS_MODE_ALWAYS
```

**9. An overlay that only ticks while paused.** Run Node Only While Paused means the animated dim
never costs anything during play.

```gdscript
func _ready() -> void:
	$PauseOverlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
```

**10. Freeze the actors for a cutscene, without pausing the tree.** Pause Node on the gameplay root
leaves the camera, the dialogue box and the timeline running.

```gdscript
func _on_cutscene_started() -> void:
	$Gameplay.process_mode = Node.PROCESS_MODE_DISABLED
```

**11. Let them go again.**

```gdscript
func _on_cutscene_ended() -> void:
	$Gameplay.process_mode = Node.PROCESS_MODE_INHERIT
```

**12. Switch a pickup off after it is taken, and back on when it respawns.** Deactivate hides AND
stops it, so nothing about the node is still ticking.

```gdscript
func _on_collected() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_respawn() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
```

**13. Turn an off-screen room off entirely.** One row on the room's root switches every enemy, timer
and particle inside it off at once.

```
On player leaves room area
  -> Room: Deactivate Node (2D)
```

**14. Ask whether a node is actually running.** Node Is Running takes the pause state into account, so
this answers the real question rather than just reading a property.

```gdscript
func _process(delta: float) -> void:
	$Debug.text = "boss active: %s" % str($Boss.can_process())
```

**15. Tell "paused" apart from "exempt from the pause".**

```gdscript
func _process(delta: float) -> void:
	if (get_tree().paused and not can_process()):
		return
```

**16. Stop the expensive per-frame work, keep collisions alive.** A distant enemy still blocks
bullets, it just stops thinking.

```gdscript
func _on_went_far_away() -> void:
	set_process(false)


func _on_came_close() -> void:
	set_process(true)
```

**17. Freeze movement without hiding anything.** Movement usually lives in the physics step.

```gdscript
func _on_stunned() -> void:
	set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	set_physics_process(true)
```

**18. Take the controls away during a scripted moment.**

```gdscript
func _on_scripted_walk_started() -> void:
	set_process_unhandled_input(false)
```

**19. Make the camera update after the player.** A higher number runs later, which removes the
one-frame lag.

```gdscript
func _ready() -> void:
	process_priority = 10
```

**20. Guard code that reaches a freshly spawned node too early.**

```gdscript
func _on_spawned(node: Node) -> void:
	if node.is_node_ready():
		node.call(&"configure")
```

**21. Confirm before quitting.** Intercept the window's close button in a ready handler, then quit
explicitly once the player says yes.

```gdscript
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _on_confirm_quit_pressed() -> void:
	get_tree().quit()
```

**22. A quit button in the menu.**

```gdscript
func _on_quit_pressed() -> void:
	get_tree().quit()
```

### Other use cases

**Level streaming on a budget.** Deactivate every room but the current one at load time and activate the neighbours as the player approaches, so a big level costs about one room of processing.

**Slow motion that is not a pause.** Leave the tree running and instead switch off the per-frame processing of the noisiest decorative systems, so the important motion stays smooth while the ambience thins out.

**A settings screen that previews live.** Run the preview node with Keep Node Running While Paused so the player can pause mid-fight, drag a slider, and watch the effect update behind the menu.

**Debug freeze key.** Bind a key to Pause Node on the gameplay root and step the world by activating it for a single frame, which gives a poor-person's frame stepper without touching the engine's debugger.

**Safe autoload handoff.** Guard any startup event that reaches into a spawned manager with Node Is Ready, which removes the "works in the editor, races on a slow machine" class of bug.

## Tips and common mistakes

- **A pause menu that also freezes is the classic mistake.** `get_tree().paused = true` freezes
  everything whose mode is Pausable, and Pausable is the default. Set the menu (and its music, and its
  animations) to Keep Node Running While Paused BEFORE you pause, or nothing in the menu will respond.
- **Deactivate Node and Pause Node write the same property.** Deactivate also hides. If a node
  disappears when you only meant to freeze it, you reached for the wrong verb.
- **Activate Node sets Inherit, not Pausable.** That is the correct undo of Deactivate for a node that
  was following its parent, which is almost all of them. A node you had deliberately set to Always
  will lose that setting.
- **Deactivating takes the whole subtree with it.** Everything under the node stops too. That is
  usually the point, but it means you cannot leave one child ticking inside a deactivated parent
  except by giving that child the Always mode.
- **Go To Scene destroys everything.** Variables held on nodes in the old scene are gone. Only
  autoloads survive, which is what they are for.
- **Restart Scene reloads the scene FILE.** Anything you spawned or changed at runtime is not
  remembered. That is what makes it a clean retry, and what makes it wrong for a mid-level checkpoint.
- **Spawn adds the copy as a child of the row's node.** A bullet spawned from the gun inherits the
  gun's transform. If it should not, spawn it under the level instead - the node-finding verbs in
  Finding And Rearranging Nodes cover getting there.
- **Handle Quit Myself reads backwards on purpose.** The dropdown labels are "Intercept" and "Allow",
  and they insert `false` and `true` respectively, because the underlying flag is
  `auto_accept_quit`. Trust the labels, not the values.
- **Handle Quit Myself is not itself a handler.** It only stops the instant quit. You still need a
  close-requested event that saves or confirms, and a Quit Game row at the end of it. Without one, the
  window simply stops closing.
- **The per-callback verbs do not survive a mode change.** Setting the process mode to Disabled and
  back to Inherit does not restore a `set_process(false)` you did earlier. Track one or the other, not
  both, on the same node.
- **`process_physics_priority`, not `physics_process_priority`.** The property reads the opposite way
  round to its setter method. The verb spells it correctly; you only meet this if you hand-write it.
- **Lower order numbers run FIRST.** The default is 0, so a node that must run after everything else
  wants a positive number, not a negative one.
- **Node Is Ready is about _ready, not about being in the tree.** For "is it in the scene tree at
  all", the Is Inside Tree verb in Finding And Rearranging Nodes is the one you want.
