# Scenes, Pausing And Turning Nodes Off

Three jobs that look like one, and cause more confusion than any other corner of the builtin
vocabulary:

1. **Changing what is on screen** - Go To Layout, Restart Layout, Spawn Scene Instance, Quit Game.
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
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Level flow** - a menu that goes to a level, a level that goes to the next one.
- **Retry** - Restart Layout is the whole death-and-respawn loop for a small game.
- **Spawning** - a scene file dropped into the world at a position, with a rotation and a group.
- **A pause menu that actually works** - the game freezes, the menu keeps running.
- **Cutscenes** - freeze the actors, keep the camera and the dialogue alive.
- **Off-screen rooms** - stop a whole area processing until the player arrives.
- **Performance triage** - turn off just the per-frame work and leave physics and input alone.
- **A confirm-on-quit dialog** - intercept the window's close button and handle it yourself.
- **Ordering fixes** - make the camera update after the thing it follows.
- **Safe access to a fresh spawn** - Node Is Ready guards code that arrives too early.

## Core concepts

- **Changing scene replaces everything.** Go To Layout swaps the whole current scene for another file.
  Nothing survives except autoloads. Restart Layout reloads exactly what is running now.
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
  Disabled - it just does not touch visibility. Pick the action that says what you meant; a reader of
  the sheet will thank you.
- **Node Is Running answers the WHOLE question.** It compiles to `can_process()`, which already takes
  both the node's mode and the game's pause state into account. Node Is Frozen By The Game Pause is
  the narrower question: the game is paused AND this node is one of the things it froze.
- **Per-callback control is finer than the node.** Set Node Per-Frame Processing, Set Node Physics
  Processing, Set Node Input Handling and Set Node Unhandled Input Handling each switch one callback,
  leaving the others alone. Use them when only one kind of work is the problem.
- **Process order is a number, and lower runs first.** Set Node Process Order and Set Node Physics
  Order are the fix for "my camera lags one frame behind the player".

## Reference tables

### Scene flow

| Name | What it does | Ships as |
|------|--------------|----------|
| Go To Layout | Switches the game to a different layout (a scene file) | `get_tree().change_scene_to_file({path})` |
| Restart Layout | Restarts the current layout from scratch | `get_tree().reload_current_scene()` |
| Pause The Game | Freezes the whole game | `get_tree().paused = true` |
| Unpause | Lets the game run again | `get_tree().paused = false` |
| Quit Game | Closes the game and exits to desktop | `get_tree().quit()` |
| Handle Quit Myself | Stops the window's X from quitting instantly | `get_tree().set_auto_accept_quit({mode})` |
| Spawn Scene Instance | Loads a scene file and adds an instance as a child | `add_child(load({path}).instantiate())` |
| Spawn Scene At | Loads a scene and drops a copy at a position | three lines, see below |
| Spawn Scene (Full) | Spawn with position, rotation and an optional group | five lines, see below |
| Spawn Scene As | Spawn under a NAME, with a record of values set on the way in and a chosen parent | eight lines, see below |
| The Spawned | The node a Spawn Scene As row made under this name, or nothing when it was never spawned or has been freed | `get_meta(&"__ef_spawn_" + <name>)`, behind a `has_meta` and `is_instance_valid` guard |
| Spawn Is Alive | True while the node spawned under this name still exists | the same guarded read, as a condition |
| On Scene Spawned | Runs when a Spawn Scene As row spawns something, handing you the name and the node | connects to the sheet's own `scene_spawned(spawn_name, node)` signal |
| Set Game Paused | Pauses or resumes the whole game | `get_tree().paused = {paused}` |
| Is Game Paused | True when the game is currently paused | `get_tree().paused` |

### The game's own mode

Pausing is the commonest thing a game does to itself, and it is rarely the only one: a cutscene, a
menu and a dialogue all want their own answers to "does the tree keep processing" and "is the mouse
shown". Declare the game's MODES once - **Edit modes…** on the modes band of the Game sheet's head -
and these six rows are that enum's vocabulary. Everything they lean on is four ordinary declarations
the dialog writes, so a project that typed them by hand is already using this.

| Name | What it does | Ships as |
|------|--------------|----------|
| Go To Mode | Moves the whole game into another mode, and says so | `mode = Mode.{mode}` (the variable's own setter emits `mode_changed`) |
| In Mode | True while the game is in this mode | `mode == Mode.{mode}` |
| Push Mode | Goes to a mode remembering the one underneath | `push_mode(Mode.{mode})` - a function the dialog declares beside the four |
| Go Back | Returns to the mode under this one, and does nothing when there is none | `go_back()` - the same, guarded on an empty stack |
| On Entering Mode | Runs the moment the game enters this mode | one handler off `mode_changed`, under `if to_mode == Mode.{mode}:` |
| On Leaving Mode | Runs the moment it leaves one, before anything answering the mode it is entering | the same handler, under `if from_mode == Mode.{mode}:` |

A GROUP says which mode its rows run in - one muted word on its head, the same shape as *runs on
host* - so every row inside stops asking for itself and the one that would have forgotten cannot.
While the game runs, Live Values shows the mode, the stack and the trail (`Menu › Playing ›
Cutscene`), and Doctor finds the two mode bugs before a player does: a mode rows can reach and never
leave, and a mode nothing uses at all.

**Handle Quit Myself** has a friendly dropdown that inserts the opposite-looking value: "Intercept
(handle it myself)" inserts `false`, and "Allow (quit immediately)" inserts `true`. Set it to
Intercept in a ready handler and the window's close button waits for your own close handler, which
then calls Quit Game explicitly.

**Spawn Scene As** is the one you can talk to afterwards. The other three build into a hidden local,
so the row after them cannot reach what was just made; this one remembers the node in the host's
metadata under the name you typed, which is why **The Spawned "boss"** works from any later row and
any later event on the same sheet. It also emits `scene_spawned(spawn_name, node)` when the sheet
declares that signal - add a **Signal** row reading `scene_spawned(spawn_name: String, node: Node)`
and put the reaction under **On Scene Spawned**, where the name and the node arrive as the row's own
payload. That is deliberately not a "last spawned" value: a loop spawning six things in one frame
would overwrite one of those six times, while a signal fires six times with the right node each time.
A reaction that only cares about one name puts a condition under the trigger comparing `spawn_name`,
the same way every other payload-carrying trigger is narrowed. Reading a name that was never spawned
is not an error and never crashes: **The Spawned** hands back nothing, and **Spawn Is Alive** is false.

```gdscript
var __spawn_figure = load("res://enemies/warden.tscn").instantiate()
__spawn_figure.position = Vector2(0, 0)
var __values_figure: Dictionary = {"max_health": 200, "tier": 3}
for __field_figure: Variant in __values_figure:
	__spawn_figure.set(__field_figure, __values_figure[__field_figure])
var __parent_figure: Node = null
(__parent_figure if __parent_figure != null else self).add_child(__spawn_figure)
set_meta(&"__ef_spawn_" + str("boss").to_utf8_buffer().hex_encode(), __spawn_figure)
if has_signal(&"scene_spawned"):
	emit_signal(&"scene_spawned", "boss", __spawn_figure)
```

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

| Name | What it does | Ships as | On |
|------|--------------|----------|----|
| Deactivate Node (2D) | Hides a node and stops it and its children running | `visible = false` then `process_mode = Node.PROCESS_MODE_DISABLED` | CanvasItem |
| Activate Node (2D) | Shows it and starts it running again | `visible = true` then `process_mode = Node.PROCESS_MODE_INHERIT` | CanvasItem |
| Deactivate Node (3D) | The same for a 3D node | `visible = false` then `process_mode = Node.PROCESS_MODE_DISABLED` | Node3D |
| Activate Node (3D) | The same undo for a 3D node | `visible = true` then `process_mode = Node.PROCESS_MODE_INHERIT` | Node3D |
| Node Is Running | True when this node is actually running right now | `can_process()` | Node |
| Set Node Process Mode | Picks any of the five modes directly | `process_mode = {mode}` | Node |
| Node Process Mode | The node's current process mode | `process_mode` | Node |

### Behaviour while the game is paused

| Name | What it does | Ships as |
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

| Name | What it does | Ships as |
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

### Later, once, and after this frame

Godot's oldest beginner trap in three readable rows, none of which suspend. Adding, freeing or
reparenting a node from inside a collision callback is the number one crash a new project hits, and
switching a collision shape off mid-physics is the number one error message. Deferring is Godot's
own answer to both, and these are that answer as vocabulary.

| Name | What it does | Ships as |
|------|--------------|----------|
| Do After This Frame | Runs one action once the frame's work is finished - the only safe moment to add, free or reparent a node | `(func(): {do}).call_deferred()` |
| Set Property (after this frame) | Sets a property at the end of the frame instead of right now | `{target}.set_deferred({property}, {value})` |
| Call Later | Runs one action after a delay, with no Timer node and WITHOUT suspending | `get_tree().create_timer(maxf({seconds}, 0.0)).timeout.connect(func(): {do}, CONNECT_ONE_SHOT)` |
| Only Once This Frame | True the FIRST time it is reached in a frame under this name, and false every other time that frame | a synthesized per-frame claim over `Engine.get_process_frames()` |

Three things separate these from the shipped Wait family. **They do not suspend**: the rows below
them keep running, which is what makes Call Later usable in the middle of a firing sequence.
**Call Later's connection is one-shot**, so a delayed beat can neither leak nor fire twice. And
**Only Once This Frame is a CONDITION** - "has this already run?" is a question, so it guards the
actions to its right exactly like the shipped Trigger Once, and it is evaluated last so it only
claims the frame once every other condition on the row has said yes.

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

**23. Spawn something and then configure it.** The name is the address, so every following row can
talk about it.

```
On boss fight started
  -> Spawn Scene As  "res://enemies/warden.tscn" as "boss" at Vector2(400, 200) with {"max_health": 200, "tier": 3}
  -> Set Property  ( The Spawned "boss" ), "target", ( player )
  -> Add To Group  ( The Spawned "boss" ), "bosses"
```

**24. Set values BEFORE the first frame.** The with-record is applied while the node is still out of
the tree, which is the only way a projectile has its damage and its owner before its first physics
step.

```
On weapon fired
  -> Spawn Scene As  "res://weapons/bolt.tscn" as "bolt" with {"damage": 12, "owner_faction": "player"}
```

**25. Choose the parent.** Spawning into a container keeps the scene tree tidy and makes "delete
every enemy" one row later.

```
On wave started
  -> Spawn Scene As  "res://enemies/slime.tscn" as "slime" into ( Get Node "Enemies" )
```

**26. React to the spawn somewhere else.** Declare the signal once, and the HUD's own sheet can show
a boss bar without the spawning sheet knowing the HUD exists.

```
On Scene Spawned  ( spawn_name, node )
  Condition: Compare Values  spawn_name = "boss"
    -> HUD Kit: Show Boss Bar  ( node )
```

```gdscript
extends Node

signal scene_spawned(spawn_name: String, node: Node)


func _on_scene_spawned(spawn_name: String, node: Node) -> void:
	if spawn_name == "boss":
		print("boss bar for ", node.name)
```

**27. Guard a row that talks to a spawn.** Things die; Spawn Is Alive is how a row asks first.

```
On Every Frame
  Condition: Spawn Is Alive  "boss"
    -> Set Property  ( The Spawned "boss" ), "target", ( player )
```

**28. Spawn a whole catalogue in one loop.** Each entry names its own spawn, so the configure row
right after it addresses the right node.

```
Condition: For Each  ( Resources In Folder "res://data/enemies" )
  -> Spawn Scene As  ( item.scene ) as ( item.id )
  -> Apply Preset To Node  ( item ), ( The Spawned ( item.id ) )
```

**29. Instance a UI row and fill it in.** The most common reason a UI sheet drops into GDScript is
that it cannot reach the row it just created.

```
On inventory opened
  Condition: For Each  ( inventory )
    -> Spawn Scene As  "res://ui/item_row.tscn" as ( item.id ) into ( Get Node "List" )
    -> Set Property  ( The Spawned ( item.id ) ), "text", ( item.name )
```

**30. Free a node from inside the collision that killed it.** Freeing during the physics step is the
crash; deferring it to the end of the frame is the fix, and the rows below still run immediately.

```gdscript
extends Node


func _on_body_entered(body: Node) -> void:
	body.take_damage(10)
	(func(): queue_free()).call_deferred()
```

**31. Switch a collision shape off at the only moment Godot permits.** Setting it directly mid-physics
is the error message every new project meets.

```gdscript
extends Node


func _ready() -> void:
	$Hitbox/Shape.set_deferred("disabled", true)
```

**32. Turn Area monitoring off safely.** Exactly the same rule, on the property that most often
carries a whole pickup's behaviour.

```gdscript
extends Node


func _on_collected() -> void:
	$Pickup.set_deferred("monitoring", false)
```

**33. Eject the shell a moment after the shot, without a Timer node.** Call Later does not suspend,
so the rows under it still run this frame.

```gdscript
extends Node


func _on_fire_pressed() -> void:
	$Weapon.fire()
	get_tree().create_timer(maxf(0.15, 0.0)).timeout.connect(func(): eject_shell(), CONNECT_ONE_SHOT)
	can_fire = false
```

**34. Close a door a beat after the player walks through it.** The connection disposes of itself, so
walking through twice cannot stack two closes.

```gdscript
extends Node


func _on_player_passed() -> void:
	get_tree().create_timer(maxf(0.8, 0.0)).timeout.connect(func(): $Door.close(), CONNECT_ONE_SHOT)
```

**35. Rebuild the inventory panel once, however many items changed.** Fifty adds in one frame become
one redraw, because the gate claims the frame the first time it is reached.

```gdscript
extends Node


func _on_item_added() -> void:
	if _once_this_frame("rebuild_bag"):
		$Bag.rebuild()
```

**36. Share one gate between several events.** Two different rows using the same name fold into a
single run per frame, which is how a panel driven by adds AND removes still redraws once.

```gdscript
extends Node


func _on_item_removed() -> void:
	if _once_this_frame("rebuild_bag"):
		$Bag.rebuild()
```

**37. Reparent a picked-up item safely.** Reparenting during a physics callback is the same family of
crash as freeing, and the same fix applies.

```gdscript
extends Node


func _on_pickup_touched(item: Node) -> void:
	(func(): item.reparent($Hand)).call_deferred()
```

**38. Mutate a group while a loop is walking it.** Deferring the removal lets the loop finish over a
stable list first.

```gdscript
extends Node


func _on_wave_cleared() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		(func(): enemy.queue_free()).call_deferred()
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
  disappears when you only meant to freeze it, you reached for the wrong action.
- **Activate Node sets Inherit, not Pausable.** That is the correct undo of Deactivate for a node that
  was following its parent, which is almost all of them. A node you had deliberately set to Always
  will lose that setting.
- **Deactivating takes the whole subtree with it.** Everything under the node stops too. That is
  usually the point, but it means you cannot leave one child ticking inside a deactivated parent
  except by giving that child the Always mode.
- **Go To Layout destroys everything.** Variables held on nodes in the old scene are gone. Only
  autoloads survive, which is what they are for.
- **Restart Layout reloads the scene FILE.** Anything you spawned or changed at runtime is not
  remembered. That is what makes it a clean retry, and what makes it wrong for a mid-level checkpoint.
- **Spawn adds the copy as a child of the row's node.** A bullet spawned from the gun inherits the
  gun's transform. If it should not, spawn it under the level instead - the node-finding rows in
  Finding And Rearranging Nodes cover getting there.
- **Handle Quit Myself reads backwards on purpose.** The dropdown labels are "Intercept" and "Allow",
  and they insert `false` and `true` respectively, because the underlying flag is
  `auto_accept_quit`. Trust the labels, not the values.
- **Handle Quit Myself is not itself a handler.** It only stops the instant quit. You still need a
  close-requested event that saves or confirms, and a Quit Game row at the end of it. Without one, the
  window simply stops closing.
- **The per-callback actions do not survive a mode change.** Setting the process mode to Disabled and
  back to Inherit does not restore a `set_process(false)` you did earlier. Track one or the other, not
  both, on the same node.
- **`process_physics_priority`, not `physics_process_priority`.** The property reads the opposite way
  round to its setter method. The action spells it correctly; you only meet this if you hand-write it.
- **Lower order numbers run FIRST.** The default is 0, so a node that must run after everything else
  wants a positive number, not a negative one.
- **Node Is Ready is about _ready, not about being in the tree.** For "is it in the scene tree at
  all", the Is Inside Tree condition in Finding And Rearranging Nodes is the one you want.
