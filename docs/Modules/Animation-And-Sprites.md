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
  Queue after a one-shot clip, or drive the switch from On Animation Finished.
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
