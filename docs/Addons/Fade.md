# Fade

**Fade** is a per-node `FadeBehavior` you attach to any sprite or UI node (any CanvasItem). It animates
the node's transparency so you can flash a pickup out of existence, ease a title in, or float a damage
number up and away, without writing tween code. It can run its whole fade-in, hold, fade-out sequence on
its own from the Inspector times, optionally free the node when it finishes, and fire a trigger at each
stage so you can chain the next beat.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Pickup and coin pops** - fade a collected item out as it rises.
- **Floating damage / heal numbers** - fade a label out over its lifetime.
- **Title and logo intros** - ease a splash image in, hold, then out.
- **Screen flashes and vignettes** - fade a full-screen ColorRect for a hit or a heal.
- **Tooltips and hints** - fade a hint panel in when hovered, out when not.
- **Ghost trails** - spawn a copy of a sprite and fade it out behind a fast mover.
- **Level transitions** - fade a black overlay in before a scene change.
- **Fading UI menus** - ease a pause menu in and out instead of a hard cut.
- **Dialogue portraits** - fade a speaker's portrait in when they start talking.
- **Warning blinks that settle** - combine with a timer to fade an alert out.

## Core concepts

- **It animates alpha.** The node's `modulate` alpha goes from 0 (invisible) to 1 (fully visible). The
  behavior works on a Node2D (a sprite) or a Control (UI), because both are CanvasItems.
- **Two simple verbs, one sequence.** **Fade In** and **Fade Out** each run one direction over a
  duration. **Start Fade** runs the whole thing: fade in over `fade_in_time`, hold for `hold_time`, then
  fade out over `fade_out_time`.
- **Fire and forget.** A fade is a tween under the hood; starting a new one cancels the old one, so
  overlapping fades never fight.
- **Triggers mark each stage.** On Faded In, On Fade Out Started, and On Faded Out let you react - play a
  sound, spawn the next thing, or free the node.
- **Optional self-cleanup.** Turn on Free On Faded Out and the node deletes itself once it has fully
  faded, which is exactly what a one-shot pickup or damage number wants.

## Setup

Attach a **Fade** behavior to any sprite or UI node. Set the Inspector times (or leave the defaults), and
either call the actions yourself or turn on Start On Ready.

A pickup that pops and disappears when collected:

```
On Ready
  -> Coin | Fade: Set Opacity  1.0
On body entered  (the player)
  -> Coin | Fade: Fade Out  0.3
Coin On Faded Out
  -> add 1 to score
```

Because Free On Faded Out frees the node, you can skip the manual "destroy" step entirely.

## ACE reference

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Fade In | duration | Fades the node up to fully visible over a duration, then fires On Faded In. |
| Fade Out | duration | Fades the node down to invisible (fires On Fade Out Started now, On Faded Out at the end). Frees the node afterwards if Free On Faded Out is on. |
| Start Fade | (none) | Runs the whole sequence from the Inspector times: fade in, hold, then fade out. |
| Stop Fade | (none) | Cancels any running fade, leaving the node at its current transparency. |
| Set Opacity | alpha | Sets the transparency directly (0 = invisible, 1 = fully visible), cancelling any running fade. |

### Conditions

| Condition | Description |
|-----------|-------------|
| Is Fading | Whether a fade is currently running. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Opacity | float | The node's current transparency, 0 to 1. |

### Triggers

| Trigger | Description |
|---------|-------------|
| On Faded In | Fires when a fade in reaches fully visible. |
| On Fade Out Started | Fires the moment a fade out begins. |
| On Faded Out | Fires when a fade out reaches invisible (and just before it frees the node, if set). |

### Inspector properties

| Property | Default | Description |
|----------|---------|-------------|
| Fade In Time | 0.5 | Seconds to fade from invisible to fully visible. |
| Hold Time | 0.0 | Seconds to stay visible between the fade in and fade out (used by Start Fade). |
| Fade Out Time | 0.5 | Seconds to fade from visible to invisible. |
| Free On Faded Out | off | Free (delete) the node once it has fully faded out. |
| Start On Ready | off | Run the full sequence automatically when the node is ready. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Use cases

**1. Collectible coin pop.**

```
Coin On body entered  (the player)
  -> Coin | Fade: Fade Out  0.25
```

With Free On Faded Out on, the coin fades and deletes itself.

**2. Floating damage number.**

```
On damage dealt
  -> spawn DamageLabel, set its text
  -> DamageLabel | Fade: Start Fade
```

Set Fade In Time small, Hold Time short, Fade Out Time longer for a rise-and-fade feel.

**3. Splash logo intro.**

```
Logo | Fade  (Start On Ready = on, Fade In Time 1.0, Hold Time 1.5, Fade Out Time 1.0)
Logo On Faded Out
  -> go to the main menu
```

**4. Screen hit flash.**

```
On player hurt
  -> HitFlash | Fade: Set Opacity  0.6
  -> HitFlash | Fade: Fade Out  0.3
```

**5. Hover tooltip in and out.**

```
On mouse entered  (a button)
  -> Tooltip | Fade: Fade In  0.15
On mouse exited
  -> Tooltip | Fade: Fade Out  0.15
```

**6. Ghost trail behind a dash.**

```
Every 0.05 seconds  (while dashing)
  -> spawn a Ghost copy at Player.position
  -> Ghost | Fade: Fade Out  0.2
```

**7. Fade to black before a scene change.**

```
On door entered
  -> BlackOverlay | Fade: Fade In  0.5
BlackOverlay On Faded In
  -> change scene
```

**8. Pause menu ease.**

```
On pause pressed
  -> PauseMenu | Fade: Fade In  0.2
On resume pressed
  -> PauseMenu | Fade: Fade Out  0.2
```

**9. Dialogue portrait entrance.**

```
On speaker changed
  -> Portrait | Fade: Fade In  0.25
```

**10. Blinking alert that settles.**

```
On low health
  -> Alert | Fade: Set Opacity  1.0
  -> Alert | Fade: Fade Out  0.8
```

**11. Only fade if it is not already fading.**

```
On hint requested
  Condition: Hint | Fade  Is Fading  (inverted)
    -> Hint | Fade: Fade In  0.2
```

**12. Read the current opacity for a custom effect.**

```
Every tick
  -> set Shadow scale to 1.0 - Sprite | Fade.Opacity()
```

**13. Dim the world during a conversation with Dialogue Kit.** Pair with the Dialogue Kit pack: fade a
dark overlay in when a conversation starts and out when it ends.

```
On Dialogue Started
  -> Dimmer | Fade: Fade In  0.3
On Dialogue Finished
  -> Dimmer | Fade: Fade Out  0.3
```

**14. Skip button interrupts a fade cleanly.** If the player skips the splash mid-fade, stop the tween
and snap to the end state instead of leaving the logo half-visible.

```
On skip pressed
  Condition: Logo | Fade  Is Fading
    -> Logo | Fade: Stop Fade
    -> Logo | Fade: Set Opacity  0.0
  -> go to the main menu
```

**15. Respawn invulnerability blink.** Chain the triggers into a loop: each fade out starts a fade in and
back, until the invulnerability window ends.

```
PlayerSprite On Faded Out  (while invulnerable)
  -> PlayerSprite | Fade: Fade In  0.15
PlayerSprite On Faded In  (while invulnerable)
  -> PlayerSprite | Fade: Fade Out  0.15
On invulnerability over
  -> PlayerSprite | Fade: Set Opacity  1.0
```

Leave Free On Faded Out off here, or the player sprite deletes itself on the first blink.

### Other use cases

**Secret-area reveal.** Cover a hidden room with a dark ColorRect and fade it out the moment the player steps inside, so the reveal feels earned rather than instant.

**Photo-mode UI hide.** Fade the whole HUD out when photo mode opens and back in when it closes, keeping screenshots clean without toggling visibility per element.

**Day-night overlay.** Fade a tinted full-screen rect in as evening falls and out at dawn, driving a whole mood shift with two actions on one node.

**Checkpoint confirmation pulse.** Snap a checkpoint glow to full opacity with Set Opacity and fade it out slowly, a quiet "saved" signal that needs no popup.

**Spectator ghost players.** Fade other players' ghosts to a fixed low opacity with Set Opacity so replays and multiplayer ghosts read as see-through without a shader.

## Tips and common mistakes

- **Attach it to the thing that should fade**, not its parent - Fade animates the node it is on.
- **Free On Faded Out is perfect for one-shots** (pickups, damage numbers). Leave it off for things you
  fade in and out repeatedly, or the node deletes itself the first time it fades out.
- **Start Fade uses the Inspector times**; Fade In and Fade Out take their own duration argument, so you
  can override per call.
- **Starting a new fade cancels the old one** - you never need to stop before starting.
- **Set Opacity is instant** and cancels any running fade; use it to snap to a starting transparency
  before a fade.
- **A Control fades from its own alpha too** - it works on UI, not just sprites.
- **Hold Time is only used by Start Fade.** Plain Fade In and Fade Out do not hold.
