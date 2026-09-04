# Animation And Sprites

Everything that makes a character move on screen without moving through space: playing a clip, stopping
it, asking whether it is still going, scrubbing the play head, queueing what comes next, flipping a
sprite to face the other way, and driving an AnimationTree state machine. These rows are **builtin** -
they need no pack enabled and no behavior attached. They come from four vocabulary modules and land in
the picker under **General Actions**, **General Conditions**, **General Expressions** and **Animation**,
scoped to the node they belong to.

There are three different ways to reach an animation here, and knowing which one you are holding is most
of the battle:

1. **Host-scoped rows** - the row runs on the AnimationPlayer / AnimatedSprite2D / AnimationTree itself.
2. **The same rows with "On node" filled in** - every host-scoped row gains an optional target, so one
   row on any sheet can drive a player somewhere else.
3. **The "(in object)" rows** - you name the OBJECT and the row finds its player for you, so
   "play walk on Player" needs no `$Rig/AnimationPlayer` path at all.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
   - [Mirror and flip](#mirror-and-flip)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Walk / idle / jump switching** driven straight off the movement rows that already exist.
- **Attack chains** where the next clip is queued instead of timed with a stopwatch.
- **Facing direction** - one Set Mirrored row instead of a scale hack.
- **Hit-pause and slow-motion** by scaling the player's speed rather than the whole engine.
- **Cutscene scrubbing** - seek to a beat, pause on a frame, resume.
- **Progress bars and sync points** read from the play head and the clip length.
- **Reaching a deep AnimationPlayer** inside an instanced character scene without a brittle path.
- **AnimationTree state machines** driven as ordinary condition and action rows.
- **Frame-exact poses** for portraits, emotes and turnaround sheets.
- **Safe playback** - ask Has Animation first so a missing clip never errors.

## Core concepts

- **The host is the node the row belongs to.** Play Animation is an AnimationPlayer action; Set Animation Frame is
  an AnimatedSprite2D action; Travel To State is an AnimationTree action. The picker only offers a row
  where its host makes sense, which is why two different conditions are both called
  **Is Animation Playing** - one asks an AnimationPlayer, one asks an AnimatedSprite2D.
- **"On node" is a free retarget.** Every host-scoped row in this guide carries an optional **On node**
  parameter. Leave it blank and the row acts on the host, compiling to exactly the bare call shown in the
  Ships-as column. Fill it and the same call is prefixed with that node, so `speed_scale = 0.5` becomes
  `Boss.speed_scale = 0.5`. Nothing else changes.
- **The "(in object)" rows search instead of pointing.** They call
  `find_children("*", "AnimationPlayer", true, false)` beneath the object you name and use the first
  match. That is what buys you "no path", and it is also their whole risk profile: first match wins, and
  a missing player means the row quietly does nothing.
- **The name comes off the scene, not off the keyboard.** Every Animation field on these rows is a
  list, filled from the scene the sheet is attached to: an AnimationPlayer's clips with their lengths
  and loop modes, an AnimatedSprite2D's flipbooks with their real frame counts, and the named markers
  on a keyframed clip's timeline. The Frame field is the same idea one level down - it offers the
  frames the picked clip actually has, so frame 7 of a five-frame flipbook is not a number you can
  reach. A name nothing in the scene declares still saves, and goes amber with the nearest real name
  offered, because a name may be built at run time; `play("atack")` used to be a silent nothing.
- **Names are StringNames.** Play Animation and its friends emit `play(&"idle")`. The `&` is a hidden
  optimization the picker never shows you; it just means the clip name is interned once instead of hashed
  on every call.
- **Assigning the current animation plays it.** Set Current Animation is a property write, not a command,
  but Godot starts the clip as a side effect. It is the direct set for when you do not need Play's
  blending arguments.
- **Queue is an end-of-clip hook, not a timer.** Queue Animation only fires when the running clip
  finishes. A looping clip never finishes.
- **An AnimationTree is addressed through paths.** Travel To State and Is In State both go through
  `get("parameters/playback")`; Set Blend and Tree Parameter take a full parameter path such as
  `"parameters/TimeScale/scale"`.

## Reference tables

The **Ships as** column is the emitted GDScript with **On node** left blank. Filling On node prefixes
that line with the node you picked.

### AnimationPlayer - play and stop

| Name | What it does | Ships as |
|------|--------------|----------|
| Play Animation | Plays a named animation on an AnimationPlayer, e.g. for walking or attacking. | `play(&{anim_name})` |
| Stop Animation | Stops the currently playing animation on the AnimationPlayer. | `stop()` |
| Is Animation Playing | True while the AnimationPlayer is playing an animation. | `is_playing()` |
| On Animation Finished | Runs when an animation finishes playing, e.g. chaining the next animation or action. Receives `anim_name`. | the `animation_finished` signal |

### AnimationPlayer - steering the play head

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Animation Speed | Scales how fast every animation on this player runs. 0 freezes it in place. | `speed_scale = {scale}` |
| Seek Animation | Jumps the play head to a time in seconds and updates the pose immediately. | `seek({time}, true)` |
| Queue Animation | Lines up an animation to play automatically when the current one ends. | `queue({animation})` |
| Pause Animation | Freezes the animation at its current position; Play resumes from here. | `pause()` |
| Set Current Animation | Switches which clip is current - assigning it starts it. | `current_animation = {animation}` |
| Get Current Animation | Reads back the name of the clip this AnimationPlayer is playing. | `current_animation` |
| Has Animation | True when this player owns a clip by that name. | `has_animation({animation})` |
| Animation Position | How many seconds into the current animation the play head is. | `current_animation_position` |
| Animation Length | The current animation's total length in seconds. | `current_animation_length` |
| Animation Speed | The player's current speed scale (1 = normal). | `speed_scale` |
| Is Between | True while the play head sits inside a slice of one named clip - the cancel window a follow-up move is allowed in, the active frames a hit counts on. | `current_animation == {animation} and current_animation_position > {from_time} and current_animation_position < {to_time}` |
| Pause For | Holds THIS animation still for a moment and then lets it run on - the per-object hit-stop. The wait ignores the game's time scale, so it un-pauses even during a slow-motion. | `pause()`, then a real-time `create_timer` wait, then `play()` |
| Play Then | Plays one clip and lines the next one up behind it, both picked from the scene's list. The waiting is the engine's own, so there is no timer to keep in step. | `play(&{animation})` then `queue(&{next})` |
| Reached Marker | True once a clip's play head has passed a named moment on its own timeline - the frame the hit lands on, in the only form a keyframed animation has. Retiming the marker in the Animation panel moves it; the row does not change. | `current_animation == {animation} and current_animation_position >= get_animation({animation}).get_marker_time({marker})` |

### AnimatedSprite2D - sprite frames

Two expressions here sound almost the same as the AnimationPlayer pair above, and they compile against
different node types. **Get Current Animation** reads an AnimationPlayer's `current_animation`;
**Current Animation** reads an AnimatedSprite2D's `animation`. Pick the one whose node is in the
row's On node cell.

| Name | What it does | Ships as |
|------|--------------|----------|
| Play Sprite Animation | Plays a named animation on an animated sprite (e.g. run or jump). | `play(&{anim})` |
| Stop Sprite Animation | Stops the animated sprite's current animation on the spot. | `stop()` |
| Set Animation Frame | Jumps the animated sprite to a specific frame number. | `frame = {frame}` |
| Set Mirrored | Mirrors the sprite horizontally, great for facing left or right. | `flip_h = {flipped}` |
| Is Animation Playing | True while the animated sprite is currently playing an animation. | `is_playing()` |
| Set Flipped | Turns the sprite upside down, or back the right way up. | `flip_v = {flipped}` |
| Set Image | Shows a different image on the sprite. | `texture = load({path})` |
| Is Playing (AnimationPlayer) | True while this animation player is running an animation. | `is_playing()` |
| Current Animation | Returns the name of the animation the sprite is currently using. | `animation` |
| Is Animation Frame | True when the sprite is showing one particular frame of one particular clip. | `animation == {animation} and frame == {frame}` |
| On Animation Frame | Runs the moment a sprite animation reaches one frame of one clip - the hit frame, the footstep, the frame a shell drops on. | the `frame_changed` signal, with the clip-and-frame question added as a condition |

### Mirror and flip

Which way the picture faces. Four hosts own a real flip flag - **Sprite2D**, **AnimatedSprite2D**,
**Sprite3D** and **TextureRect** - and these rows are offered on each of them. They set (or read) that
node's OWN flag, so the picture turns and nothing else does: a hitbox, a muzzle point or a ray under
the same character keeps pointing exactly where it pointed before. When those have to turn too, mirror
the whole object instead - negating the X scale of the Node2D that owns the character turns every
child with it, and the row that says so is **Set Mirrored (whole object)** on that node.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Mirrored | Mirrors this node's picture left-to-right - the way a 2D character faces. | `flip_h = {mirrored}` |
| Set Flipped | Turns this node's picture upside down, or puts it back the right way up. | `flip_v = {flipped}` |
| Is Mirrored | True while this node's picture is mirrored - which way the character is facing. | `flip_h` |
| Is Flipped | True while this node's picture is upside down. | `flip_v` |

The AnimatedSprite2D pair listed under sprite frames above is the same two lines, named `{flipped}`
rather than `{mirrored}` in the parameter cell; the emitted GDScript is identical either way.

### Object-level - name the object, not its player

These take a **Target** (the object) and find the player themselves. Each one is guarded, so a target
with no player is a no-op rather than an error.

| Name | What it does | Ships as |
|------|--------------|----------|
| Play Animation (in object) | Plays a named animation by auto-finding the object's AnimationPlayer for you. | `var __ap_{uid} := {target}.find_children("*", "AnimationPlayer", true, false).pop_front() as AnimationPlayer` then `if __ap_{uid}: __ap_{uid}.play(&{anim})` |
| Stop Animation (in object) | Stops the object's animation by auto-finding its AnimationPlayer. | the same lookup, then `__ap_{uid}.stop()` |
| Restart Animation (in object) | Replays a named animation from the very start, e.g. retriggering an attack. | the same lookup, then `stop()` followed by `play(&{anim})` |
| Is Animating (in object) | True when any AnimationPlayer beneath the object is currently playing. | `{target}.find_children("*", "AnimationPlayer", true, false).any(func(__p): return __p.is_playing())` |
| Play Sprite Animation (in object) | Plays a named sprite animation via the object's AnimatedSprite2D, found automatically. | an `AnimatedSprite2D` lookup, then `.play(&{anim})` |
| Flip Sprite (in object) | Mirrors the object's sprite horizontally, e.g. flipping to face left or right. | an `AnimatedSprite2D` lookup, then `.flip_h = {mirrored}` |
| Set Sprite Frame (in object) | Shows a specific frame on the object's AnimatedSprite2D, found automatically. | an `AnimatedSprite2D` lookup, then `.frame = {frame}` |

### AnimationTree - state machines and blends

| Name | What it does | Ships as |
|------|--------------|----------|
| Set AnimationTree Active | Turns this AnimationTree's playback on or off. | `active = {active}` |
| Travel To State | Travels the state machine to a named state, and reads as *Travel to animation state "Hurt"*. | `get("parameters/playback").travel({state})` |
| Set Blend | Sets an AnimationTree parameter like a blend amount, condition or timescale. | `set({path}, {value})` |
| Is Tree Active | True when this AnimationTree is currently active and playing. | `active` |
| Is In State | True when the state machine is sitting in the named state. | `get("parameters/playback").get_current_node() == {state}` |
| Current State | Returns the state-machine node the tree is currently in. | `get("parameters/playback").get_current_node()` |
| Tree Parameter | Returns the current value of an AnimationTree parameter. | `get({path})` |

### AnimationTree - travelling, blending and the two state moments

The rows above are the tree's oldest vocabulary and are still exactly what they were. These are the
rest of what a blend tree does, and every one of them is a value written into, or read out of, one of
the engine's own parameter paths. The **State** field on Travel To State, Is In State, Current State Is
and Jump To lists the states the tree in your scene really declares; the **Blend space** and **Layer**
fields list its blend nodes, each said with how many dimensions it has, so a Vector2 never goes into a
space that is a line.

| Name | What it does | Ships as |
|------|--------------|----------|
| Jump To | Puts the state machine straight into a state, ignoring every transition on the way - a respawn, a cutscene cut. | `get("parameters/playback").start({state})` |
| Is In Any State | True while the machine is in ANY of several states - the attack that may start from a stand or a run. | `get("parameters/playback").get_current_node() in {states}` |
| Set Blend Position | Moves where a blend space is sampled: the stick into a walk-run space, the aim height into a lean. | `set("parameters/{space}/blend_position", {value})` |
| Blend Toward | The same move taken over seconds instead of at once, as a tween on the tree's own parameter. | `create_tween().tween_property({target}, "parameters/{space}/blend_position", {value}, {seconds})` |
| Blend Layer | Fades a Blend2 or Add2 layer in or out over seconds - the aim pose that arrives when a target is locked. | `create_tween().tween_property({target}, "parameters/{layer}/blend_amount", {amount}, {seconds})` |
| Set Condition | Writes one of the booleans the tree's transitions advance on, so the tree decides WHEN and the sheet only says what is true. | `set("parameters/conditions/{condition}", {value})` |
| Set Tree Time Scale | Slows or speeds everything under one TimeScale node, without touching the game's own clock. | `set("parameters/{node}/scale", {scale})` |
| Time In State | How many seconds the machine has been playing its current state. | `get("parameters/playback").get_current_play_position()` |
| On State Entered | Runs the moment the machine enters a state, with the state's name handed to the event. | the playback object's own `state_started` signal |
| On State Left | Runs the moment the state it was in finishes. | the playback object's own `state_finished` signal |

**On State Entered and On State Left are not signals of the AnimationTree node.** They belong to the
playback object the tree keeps under `parameters/playback`, so the connect line the sheet writes
reaches through the tree to it - `get_node("Anim").get("parameters/playback").state_started.connect(...)` -
which is exactly the line a hand-written project writes to hear the same thing.

**Travel To State is the one to reach for.** It walks the machine through its own transitions, so the
blend times, the advance conditions and the transition priorities the tree was drawn with all still
apply. Jump To ignores all of that on purpose, and is the cut rather than the everyday move.

### Reaching a marker as a moment

**Reached Marker** stays true for the rest of the clip, which is the right question for a window. A
moment needs the crossing itself, and that is the pair below: applying the trigger adds the crossing
question as a condition you can see and edit, exactly as On Animation Frame adds its frame question.

| Name | What it does | Ships as |
|------|--------------|----------|
| On Animation Reached Marker | Runs on the one frame a clip's play head crosses a named moment on its timeline. | the mixer's own `mixer_updated` signal, with the crossing as a condition under it |
| Just Reached Marker | True on the ONE frame the play head passes the marker, false on every frame after it. | the marker comparison, plus a remembered "had it already passed" beside it |

### Root motion - the animator's step, taken into the body

Root motion is the animation moving the character rather than a number in the sheet moving it. Godot
answers how far the root moved this frame; the row's whole job is dividing that by the frame time,
because a velocity is a distance per second and root motion is a distance per frame. Put the row in a
physics tick, **before** Move And Slide.

| Name | What it does | Ships as |
|------|--------------|----------|
| Apply Root Motion (Movement 2D) | Moves and turns a CharacterBody2D by whatever the animation's root moved this frame, with an optional scale. | the tree's `get_root_motion_position()` read once, then `velocity = Vector2(...) / delta * {scale}` and a turn by the root's own rotation |
| Apply Root Motion (Movement 3D) | The same on a CharacterBody3D, turned by the body's own basis first, because the animation was authored facing forward. | `velocity = (basis * {tree}.get_root_motion_position()) / delta * {scale}`, then `quaternion *= {tree}.get_root_motion_rotation()` |

### Bones - pointing, reading and holding

Six rows, in 2D and 3D twins. In 3D a bone is an index inside a Skeleton3D and a name resolves to one;
in 2D a bone IS a node, a Bone2D under the Skeleton2D, so the 2D rows are node-scoped on Bone2D and
address it the way every other 2D row addresses a node.

| Name | What it does | Ships as |
|------|--------------|----------|
| Point Bone At (Skeleton 3D) | Aims one bone at a node and keeps aiming, easing in over the seconds you give it. | four assignments on the engine's own LookAtModifier3D - `bone_name`, `target_node`, `duration`, `influence` |
| Point Bone At (Skeleton 2D) | Turns this bone toward a node, a frame's worth at a time. | `global_rotation = lerp_angle(global_rotation, (...).angle(), clampf(delta / ...) * {weight})` |
| Bone Position (Skeleton 3D) | Where one bone is in the WORLD - the hand a weapon hangs off, the head a name tag floats over. | `(global_transform * get_bone_global_pose(find_bone({bone}))).origin` |
| Bone Position (Skeleton 2D) | The same question in 2D, where a bone knows where it is. | `global_position` |
| Set Bone Pose Override (Skeleton 3D) | Holds one bone in a pose of your own over whatever is playing, by an amount. | `set_bone_global_pose_override(find_bone({bone}), {pose}, {amount}, true)` |
| Set Bone Pose Override (Skeleton 2D) | The same, on a 2D skeleton, by bone index. | `set_bone_local_pose_override({bone}, {pose}, {amount}, true)` |

**The 3D point row sets a modifier up rather than doing the aiming itself.** A LookAtModifier3D already
knows how to ease into a look, how to stop at an angle limit and how to blend out again, and none of
that is worth writing again in a row. Add the modifier under the skeleton once; the row is the sheet's
hand on its dials. The 2D twin has no such modifier to lean on - the 2D modification stack is the old
path - so it does the one line the modifier would have done, every tick it is asked.

**Bone Position in 3D is the line everybody gets wrong the first time.** `get_bone_global_pose` is
global to the SKELETON, not to the world, so a muzzle flash placed straight at it appears wherever the
skeleton's origin happens to be. The row multiplies it back out by the skeleton's own transform.

### What the Doctor says about a tree

Two notes, and both describe something that runs today without an error and without doing what the row
says. Neither draws anything in the sheet: the row wears the quiet amber state, and the words live in
the triage inbox and in the row's help strip when it is selected.

- **A state nobody declared.** `travel(&"Swng")` walks nowhere - the machine looks for a state by that
  name, does not find one, and stays where it was. The note names the file, the state and the nearest
  one the tree really has.
- **A vector into a line.** A Vector2 written into a ONE-dimensional blend space is accepted by `set()`,
  and the space keeps only what it can use - so the blend is driven by the x alone, for ever.

Both are answered by the SCENE rather than by the sheet, so a script no single scene runs has nothing
to be checked against and is passed over in silence.

### Animations that call back - method tracks

An animation can call a function on the animated node: that is a **method track**, and it is the only
contract in Godot that both sides can honour without either side saying so. **On Animation Event** is
that function, written as an event.

| Name | What it does | Ships as |
|------|--------------|----------|
| On Animation Event | Runs when an animation's method track reaches its key. Name the event in plain words and call the same name from the track. | a plain function - `"hit frame"` becomes `func _on_hit_frame() -> void:` |

Name the event **hit frame** here and the track's method must be `_on_hit_frame`. Open a script whose
functions an animation calls and the sheet says so out loud: the row reads
*On animation event "hit frame" of "punch"*, because the `.tscn` or `.tres` holding the animation names
the function and the sheet reads it. **Project Doctor** warns when a method track calls a function no
script defines - the bug where the key plays, nothing happens, and nothing is reported.

## Use cases

**1. Play a clip when the node wakes up.** The plainest possible animation row, on an AnimationPlayer
sheet.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	play(&"idle")
```

**2. Half speed for a death scene.** Set Animation Speed scales this player only, so the rest of the
game keeps running at full rate.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	speed_scale = 0.5
	play(&"death")
```

**3. Guard a clip that might not exist.** Has Animation as the condition, Play Animation as the action -
a shared enemy sheet where only some enemies have a `taunt` clip.

```
On Ready
  Condition: Has Animation  "taunt"
    -> Play Animation  "taunt"
```

**4. A combo chain with no timers.** Queue Animation lines up the follow-up, and the player switches to
it the instant the current clip ends.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	play(&"attack_1")
	queue("attack_2")
	queue("idle")
```

**5. Drop back to idle after an attack.** One queued clip is the whole "return to neutral" rule, with no
On Animation Finished row and no stopwatch.

```
On attack pressed
  -> Play Animation  "attack"
  -> Queue Animation  "idle"
```

**6. Chain on the trigger instead.** When you need to do more than play the next clip, use the trigger
and read the name it hands you.

```
On Animation Finished
  Condition: anim_name = "attack"
    -> Play Animation  "idle"
    -> Set value  can_act = true
```

**7. A hit-pause on an exact frame.** Pause holds the pose; Play resumes from where it stopped, which
Stop Animation does not.

```
On hit landed
  -> Pause Animation
  -> Wait  0.08 seconds
  -> Play Animation  (resume)
```

**7a. The same hit-pause as one row.** Pause For is the three lines above written once, and its wait
ignores the game's time scale - so the pose un-freezes even if a slow-motion is running.

```
On hit landed
  -> Pause For  0.08 s
```

**7b. A cancel window.** Between 0.3 s and 0.6 s of the uppercut, the next move may interrupt it. Is
Between is that slice as one question, and the row says which clip the clock belongs to.

```
On punch pressed
  Condition: Is Between  0.3 s and 0.6 s of "uppercut"
    -> Play Animation  "punch"
```

**7c. The hit frame itself.** On Animation Frame fires the moment the sprite reaches frame 3 of the
punch, which is where the hitbox belongs - not on a timer that guesses at it.

```
On Animation Frame  "punch" frame 3
  -> Set node enabled  $Hitbox = true
```

**7d. The same thing from the animation's side.** A method track on the punch clip calls
`_on_hit_frame`, and On Animation Event IS that function. Use this when the timing lives with the
animator rather than with the programmer.

```
On Animation Event  "hit frame"
  -> Set node enabled  $Hitbox = true
```

**8. Scrub to a beat.** Seek Animation jumps the play head and refreshes the pose in the same frame, so
a cutscene can start two seconds in.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	play(&"cutscene")
	seek(2.0, true)
```

**9. An animation progress bar.** Animation Position over Animation Length is a 0-to-1 fraction.

```
Every Frame
  -> Set Property  ProgressBar.value = Animation Position / Animation Length * 100
```

**10. Freeze the frame for a photo mode.** Speed 0 leaves the pose exactly where it is without touching
the current animation, so 1 puts it straight back.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	speed_scale = 0.0
```

**11. Face the way you are moving.** Set Mirrored on an AnimatedSprite2D is the whole facing rule.

```gdscript
extends AnimatedSprite2D


func _process(delta: float) -> void:
	flip_h = true
```

**12. A frame-exact portrait.** Stop the sprite, then park it on one frame - an emote wheel or a
turnaround sheet.

```gdscript
extends AnimatedSprite2D


func _ready() -> void:
	stop()
	frame = 3
```

**13. Only start a run cycle once.** Current Animation reads the AnimatedSprite2D's clip name back, so
the row is skipped while it is already running. On an AnimationPlayer rig, Get Current Animation is
the read-back to use instead.

```
Every Frame
  Condition: Current Animation != "run"
    -> Play Sprite Animation  "run"
```

**14. Animate the object, not its rig.** The player is somewhere beneath the character scene and you do
not want to know where.

```
On enemy spotted player
  -> Play Animation (in object)  Target: Enemy, "alert"
```

**15. Retrigger an attack that is already playing.** Plain Play does nothing when the same clip is
already running; Restart Animation (in object) stops it first, so frame 0 comes back.

```
On attack pressed
  -> Restart Animation (in object)  Target: Player, "swing"
```

**16. Do not interrupt yourself.** Is Animating (in object) is true when ANY player beneath the object
is running, which is the guard you want before starting a new move.

```
On attack pressed
  Condition: Is Animating (in object)  Target: Player   (inverted)
    -> Play Animation (in object)  Target: Player, "swing"
```

**17. Drive a state machine as rows.** Travel To State is an ordinary action, Is In State an ordinary
condition, so a whole animation state machine reads as event sheet logic.

```
On jump pressed
  Condition: Is In State  "idle"
    -> Travel To State  "jump"
```

**18. Blend a tree parameter live.** Set Blend writes any path the tree exposes - a blend
position, a timescale, a condition.

```gdscript
extends AnimationTree


func _process(delta: float) -> void:
	set("parameters/TimeScale/scale", 0.5)
```

**19. Turn the tree off for a scripted pose.** With the tree inactive, plain AnimationPlayer rows own the
rig again; turn it back on when the cutscene ends.

```
On cutscene starts
  -> Set AnimationTree Active  false
On cutscene ends
  -> Set AnimationTree Active  true
```

**20. Drive one player from another sheet.** Leave the host alone and fill **On node** - the row emits
the identical call with the node in front of it.

```
On boss defeated
  -> Set Animation Speed  0.25   On node: BossRig
```

**21. Attack, then idle.** Play Then is ONE row that writes both lines, so the follow-up is the
engine's own end-of-clip hook rather than a timer somebody has to keep in step with the animation's
length, and both names are picked from the scene's list. The two lines are ordinary GDScript, so a
file that already had them opens as the Play and Queue rows they are - the row is a way to write the
pair, not a shape the file has to be in.

```gdscript
extends AnimationPlayer


func _ready() -> void:
	play(&"attack")
	queue(&"idle")
```

**22. The spellings you already wrote open too.** A plain-string `play` and a StringName `queue` are
both ordinary GDScript that people write by habit, and both open as rows through a node path. Whichever
spelling you used is the spelling the file gets back when you save.

```gdscript
extends Node2D


func _ready() -> void:
	$Anim.play("idle")
	$Anim.queue(&"swing")
```

**23. The stick drives the walk-run blend.** One row in a tick, and the blend space's name comes off
the tree rather than out of your memory. A hand-written `set` of the same path opens as the same row.

```gdscript
extends CharacterBody2D


func _physics_process(_delta: float) -> void:
	$Anim.set("parameters/Locomotion/blend_position", move_input)
```

**24. Swing on the press, but only from a stand or a run.** Is In Any State is the question a combo
system asks all day: several states, one row, and Travel To State walks through the transitions the
tree was drawn with rather than cutting to the state.

```gdscript
extends CharacterBody2D


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and $Anim.get("parameters/playback").get_current_node() in ["Idle", "Run"]:
		$Anim.get("parameters/playback").travel(&"Swing")
```

**25. The aim layer arrives when the target is locked.** Blend Layer is a tween on the tree's own
parameter, so nothing is stepped by hand and nothing has to be un-stepped when the lock is dropped.

```gdscript
extends Node3D


func _on_locked_on() -> void:
	create_tween().tween_property($Anim, "parameters/Aim/blend_amount", 1.0, 0.2)
```

**26. The animator's step moves the character.** Root motion in a physics tick, before Move And Slide,
so a swing that lunges forward lunges exactly as far as the animator drew it.

```gdscript
extends CharacterBody3D


func _physics_process(delta: float) -> void:
	velocity = (basis * $Anim.get_root_motion_position()) / delta * 1.0
	quaternion *= $Anim.get_root_motion_rotation()
	move_and_slide()
```

**27. The head follows the thing you locked onto.** Point Bone At sets the engine's own look-at
modifier up once; the modifier keeps aiming every frame after, easing over the time you gave it.

```gdscript
extends Node3D


func _on_locked_on() -> void:
	$Rig/Skeleton3D/LookAt.bone_name = "Head"
	$Rig/Skeleton3D/LookAt.target_node = $Rig/Skeleton3D/LookAt.get_path_to(locked_target)
	$Rig/Skeleton3D/LookAt.duration = 0.2
	$Rig/Skeleton3D/LookAt.influence = 1.0
```

### Other use cases

**Slow-motion finisher.** Set Animation Speed to 0.2 on the attacker and the victim together, restore both on the trigger that ends the sequence, and the whole effect is four rows with no engine time scale involved.

**Lip-sync markers.** Seek Animation to a known second for each dialogue line, then read Animation Position every frame to decide which mouth frame the portrait should show.

**Loading spinner from a sprite.** An AnimatedSprite2D with Play Sprite Animation on ready and Stop Sprite Animation when the load finishes needs no code, no tween and no timer.

**Damage flash on a shared rig.** Set Sprite Frame (in object) to a white silhouette frame, wait, then set it back, all addressed at the object so the same two rows work for every enemy scene.

**Menu idle breathing.** Queue Animation a second, slightly different idle after the first so the menu character never loops the exact same motion twice in a row.

## Tips and common mistakes

- **Two conditions share the name Is Animation Playing.** One is an AnimationPlayer condition, one is an
  AnimatedSprite2D condition. Both emit `is_playing()`. The picker shows you the one your host supports,
  so the confusion only bites when you retarget with On node - point an AnimationPlayer condition at a
  sprite and you get the wrong node's answer, not an error.
- **Play does not restart a clip that is already playing.** Use Restart Animation (in object), or Seek
  Animation to 0, or Stop Animation followed by Play Animation.
- **Queue Animation never fires on a looping clip.** A loop has no end, so the queue sits there forever.
  Queue after a one-shot clip, or drive the switch from On Animation Finished. The sheet says so as
  well: a queue behind a clip the scene declares as looping grows a note on the row, because the loop
  mode is a fact the scene already knows.
- **A keyframed clip has markers, not frames.** A skeletal swing has no frame 3 to click on, so
  "which frame does the hit land on" is answered by a named moment on the timeline instead - add the
  marker in the Animation panel and ask Reached Marker for it. Retiming the animation moves the
  marker with it, which a stored number would not do. Frames are the flipbook question, and the Frame
  field only offers the ones an AnimatedSprite2D's clip really has.
- **Pause Animation and Stop Animation are not the same.** Pause keeps the play head; Stop discards it.
  A "resume" built on Stop restarts from the beginning.
- **Set Current Animation starts playing.** It looks like a harmless property write. If you only want to
  select a clip without playing it, follow it with Pause Animation.
- **Animation Length can be 0.** A player with nothing current returns 0, so a progress bar that divides
  by it produces an error or a NaN. Gate the row on Is Animation Playing.
- **The "(in object)" rows take the FIRST match in tree order.** A character scene with two
  AnimationPlayers (a rig and a UI flourish, say) will get whichever comes first in the subtree. Target
  the player directly with On node when the object has more than one.
- **A missing player is silent, by design.** The "(in object)" templates are wrapped in an `if`, so
  nothing errors and nothing happens. If a row seems ignored, check that the object really contains a
  player of that type - Has Child Of Type is the quick test.
- **Set Animation Frame is overwritten by playback.** Setting a frame on a sprite that is still playing lasts
  exactly one frame. Stop Sprite Animation first.
- **Set Blend's path is inserted literally.** It is a plain text parameter, not an expression
  field, so `parameters/Blend2/blend_amount` is typed exactly as the tree spells it. A wrong path fails
  quietly rather than erroring.
- **Travel To State needs an active tree.** Is Tree Active is the guard; travelling into an inactive tree
  does nothing visible and looks like the state name is wrong.
- **On node is blank-by-default on purpose.** A blank target compiles byte-for-byte to the original host
  call, which is why filling it in later never rewrites the rest of your sheet.
