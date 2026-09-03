# Camera Rail - A Shot List For A Camera

Attach a rail under a camera and that camera becomes directable from event rows. **Fly Along**
walks it down a drawn path over a number of seconds, **Hold** parks it on a beat, **Blend To**
travels it onto another camera and hands the view over, and **Cut To** switches outright.
Every shot that runs ends in a trigger, so a cutscene is a chain of rows rather than a coroutine
(the two shots that refuse to start, and Stop Rail, are the deliberate exceptions - see Tips).

Two packs, one vocabulary: `CameraRailBehavior` directs a **Camera2D** along a **Path2D**, and
`CameraRail3DBehavior` directs a **Camera3D** along a **Path3D**, keeping a node in frame while it
flies and carrying the field of view through a blend.

## Where this pack shines

- **Cutscenes without a coroutine.** On Shot Finished starts the next shot, so a five-beat
  sequence is five rows anyone on the team can read and reorder.
- **Handing the view over cleanly.** Blend To lands the rail's camera exactly on another camera
  and then makes that one current, so the shot after the blend belongs to whatever normally
  drives it - a follow behaviour, a player camera, a second rail.
- **Intros, fly-throughs and establishing shots.** Draw the route in the editor, name the seconds,
  and the move is authored where it can be seen rather than typed as numbers.

## Setup

1. Add a `Camera2D` (or `Camera3D`) where the shot should start, and attach `CameraRailBehavior`
   (or `CameraRail3DBehavior`) as a child of it.
2. Draw the route as a `Path2D` (or `Path3D`) in the same scene and drop it on the rail's `route`
   property, or hand a path to Fly Along per shot.
3. Leave `current_on_ready` on if the rail's camera should hold the view from the first frame; turn
   it off when another camera opens the scene and the rail takes over later.

```
On Ready       -> Rail | Camera Rail: Fly Along  route, 4, Ease in and out
On Shot Finished -> Rail | Camera Rail: Hold  1
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- fly along *path* over **seconds**s, **ease**
- blend onto *camera* over **seconds**s, **ease**
- hold this shot for **seconds**s
- cut to *camera*
- stop the rail

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Fly Along | `path` (Path2D / Path3D), `seconds`, `ease`; 3D also `look_at` (Node3D) | Walks the rail's camera from the start of the drawn route to its end over the seconds given, and gives that camera the view as the flight starts. A `null` path walks the Inspector's `route`; 0 seconds takes `shot_seconds`; an empty ease takes `shot_ease`. In 3D, `look_at` is a node the camera turns to face the whole way, or `null` to keep the heading it was left with. |
| Action | Cut To | `camera` (Camera2D / Camera3D) | The hard cut: the named camera takes the view immediately. Whatever shot was running stops where it stands and On Shot Finished does not fire, because the cut is the ending. |
| Action | Blend To | `camera`, `seconds`, `ease` | Travels the rail's camera onto the named one - position and rotation together with the zoom (2D) or the field of view (3D) - then hands the view to it. The travel starts from whatever shot is on screen: if the rail had handed the view away, its own camera stands on that shot first and takes the view back. |
| Action | Hold | `seconds` | Parks the rail for that long and then fires On Shot Finished, leaving the view exactly where it is - so a hold after a Cut To is the beat on THAT camera. 0 seconds falls back to `shot_seconds`. |
| Action | Stop Rail | - | Halts the shot where it stands, WITHOUT firing On Shot Finished. The next Fly Along, Hold or Blend To starts a fresh shot. |
| Condition | Is Flying | - | True only while a Fly Along run is travelling. A Hold and a blend are not flights. |
| Expression | Rail Progress | - | How far through the current shot the rail has come, 0 at its start and 1 when it finished. It is the time through the shot, before the ease bends it, and it keeps its last value once the shot ends. |
| Trigger | On Shot Finished | - | A Fly Along run or a Hold reached its end. The row that starts the next shot. |
| Trigger | On Blend Finished | - | A Blend To landed and handed the view over. |

The four ease words are the same on every verb that takes one: `linear`, `ease_in`, `ease_out`
and `ease_in_out`. A word the pack does not know plays the shot straight rather than freezing it.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `route` | `null` | The `Path2D` / `Path3D` Fly Along walks when a row hands it no path of its own. |
| `shot_seconds` | `3.0` | How long a shot lasts when a row asks for 0 seconds or less. |
| `shot_ease` | `ease_in_out` | The curve a shot follows when a row names no ease of its own. |
| `current_on_ready` | `true` | Makes the rail's own camera current the moment the scene runs. |

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is
attached:

- `$CameraRailBehavior.rail_progress()` inserts the **Rail Progress** entry straight into any expression
- `$CameraRailBehavior.shot_seconds` inserts the **Shot Seconds** knob the same way

The `$CameraRailBehavior` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag. The 3D twin answers to `$CameraRail3DBehavior` with the same
entries. Attaching the behaviour at runtime instead? Tick **Robust behaviour lookups** in the
dictionary and the same entries insert as `get_node_or_null("CameraRailBehavior")` chains, which
survive auto-named children.

## Use cases

### 1. The opening fly-through

The camera the level opens on is the rail's own, so nothing else has to hand it the view.

```
On Ready -> Rail | Camera Rail: Fly Along  intro_route, 6, Ease in and out
```

### 2. Handing the view to the player camera

The intro ends where the player camera is parked, so the swap is invisible.

```
On Shot Finished -> Rail | Camera Rail: Blend To  PlayerCamera, 1.2, Ease out
On Blend Finished -> set gameplay_started to true
```

### 3. A three-beat cutscene

Fly, hold on the reveal, then blend to the camera that was watching the door.

```
On Cutscene Start -> Rail | Camera Rail: Fly Along  approach, 3, Ease in
On Shot Finished
  Condition: beat = 0 -> add 1 to beat
                      -> Rail | Camera Rail: Hold  1.5
  Condition: beat = 1 -> add 1 to beat
                      -> Rail | Camera Rail: Blend To  DoorCamera, 1, Ease in and out
```

### 4. A skip button

Stop Rail halts the shot without announcing it, so a skip does not fire the row that would have
started the next beat. Cut straight to where the scene should resume.

```
On "ui_cancel" pressed
  Condition: Rail | Camera Rail: Is Flying -> Rail | Camera Rail: Stop Rail
                                           -> Rail | Camera Rail: Cut To  PlayerCamera
```

### 5. A letterbox that only belongs on a dolly

Is Flying is true for a flight and false for a hold or a blend, which is exactly the question a
cinematic border wants asked.

```
Every tick
  Condition: Rail | Camera Rail: Is Flying     -> show LetterBox
  Condition: [X] Rail | Camera Rail: Is Flying -> hide LetterBox
```

### 6. A progress bar for a long fly-through

Rail Progress runs 0 to 1 over whatever shot is running, so one expression drives a bar, a fade or
a music cue.

```
Every tick -> set SkipHint.modulate.a to Rail | Camera Rail: Rail Progress
```

### 7. Two rails, one scene

Give each act its own rail with its own route, and let one hand the view to the other's camera.

```
On Act Two -> ActOneRail | Camera Rail: Blend To  ActTwoCamera, 1.5, Ease in and out
```

### 8. A security camera sweep

Loop a rail forever by restarting it on its own finish trigger - a patrol for the view instead of
for a guard.

```
On Shot Finished -> Rail | Camera Rail: Fly Along  sweep, 8, Linear
```

### 9. A boss reveal

Cut hard to the boss camera, hold on it, then blend back. The hard cut is the punch; the blend
back is the recovery.

```
On Boss Spawn -> Rail | Camera Rail: Cut To  BossCamera
              -> Rail | Camera Rail: Hold  2
On Shot Finished -> Rail | Camera Rail: Blend To  PlayerCamera, 0.8, Ease out
```

### 10. Shake on top of the shot

Screenshake and the zoom punch from the Juice pack ride on whichever camera is CURRENT, and while
a rail is flying that is the rail's own camera. Neither pack has to know about the other.

```
On Shot Finished -> Juice: Shake  0.6
```

### 11. A menu background that never sits still

A slow linear loop around the title scene reads as a live world behind the buttons.

```
On Ready         -> Rail | Camera Rail: Fly Along  title_orbit, 20, Linear
On Shot Finished -> Rail | Camera Rail: Fly Along  title_orbit, 20, Linear
```

### 12. Keeping the hero in frame (3D)

The 3D twin turns the camera onto a node for the whole flight, so a crane shot stays composed
without a single rotation keyframe.

```
On Ready -> Rail | Camera Rail 3D: Fly Along  crane, 5, Ease in and out, Hero
```

### 13. A lens change that travels with the move (3D)

Blend To carries the field of view across, so parking a wide-angle camera at the far end is how
you author a lens change - no separate FOV row.

```
On Shot Finished -> Rail | Camera Rail 3D: Blend To  WideCamera, 2, Ease in and out
```

### 14. A replay camera

Park a rail on a route that follows the finish straight, turn `current_on_ready` off, and cut to
it only when the replay starts.

```
On Replay Start -> Rail | Camera Rail: Cut To  ReplayCamera
                -> Rail | Camera Rail: Fly Along  finish_straight, 4, Ease out
```

### 15. A door that watches itself open

A short hold with nothing moving is still a shot, so the beat between two moves is a row rather
than a timer somebody has to remember to cancel.

```
On Door Opening -> Rail | Camera Rail: Hold  0.75
On Shot Finished -> Rail | Camera Rail: Blend To  PlayerCamera, 0.5, Ease out
```

### Other use cases

**Photo mode.** A rail with a hand-drawn route gives a photo mode a fixed, repeatable dolly the
player can scrub with Rail Progress.

**Tutorial pans.** Each tutorial step flies the view to the thing it is talking about and holds
there until the player acts.

**Level select.** One route through a hub world, with a Hold at each stop, turns a menu into a
guided tour.

**Death cam.** Cut to a camera framing the killing blow, hold, then blend back to the respawn
camera as the retry prompt appears.

**Credits crawl through the world.** A twenty-second linear flight through the finished level is a
credits sequence with no separate scene to build.

## Tips and common mistakes

- **The rail directs the camera it is attached to.** Attach it under the `Camera2D` / `Camera3D`
  you want moved, not under the thing being filmed.
- **One shot at a time.** Fly Along, Hold and Blend To each replace whatever was running. That is
  deliberate: two shots driving one camera at once have no meaning.
- **Stop Rail is silent on purpose.** It does not fire On Shot Finished, so a chain built on that
  trigger stops rather than jumping to its next beat. That is what makes it the right row for a
  skip.
- **A moving shot takes the view; a hold does not.** Fly Along and Blend To make the rail's own
  camera current as the shot starts, because a move nobody can see is not a move. Hold leaves the
  view where it is, which is what makes the Cut To - Hold - Blend To chain read: the beat belongs
  to the camera the cut put up.
- **A route with nothing drawn on it starts no flight, and says nothing.** A `Path2D` whose curve
  has no length is refused rather than divided by - but the refusal is silent and On Shot Finished
  does not fire, so a chain waiting on that trigger stops there. Check the route is drawn before
  building the rest of the sequence on it.
- **A blend target freed mid-blend ends the blend quietly.** The shot stops where it stands and On
  Blend Finished does not fire, because there is no camera left to hand the view to. Keep the
  cameras a cutscene blends between alive for the length of it.
- **Turn `current_on_ready` off for a rail that waits.** Two rails both claiming the view on the
  first frame is a coin toss; let the one that opens the scene hold it and have the other cut in.
- **Blend To hands the view over, Cut To does not blend.** If the two cameras are already framed
  the same, a blend of 0 seconds is a cut that still fires On Blend Finished, which is sometimes
  the tidier chain.

## Already written it by hand? It reads as this pack

A dolly written by hand is usually a `Tween` on `global_position` plus a `PathFollow2D` nudged in
`_process`, and both of those still open as their own plain rows - the tween call, the property
write, the sampled point. Nothing here silently claims those lines.

What the pack replaces is the bookkeeping around them: the seconds, the ease, the arrival, and the
handover to the next camera, which by hand is a coroutine with an `await` in the middle of it.
Fly Along plus On Shot Finished is that whole shape as two rows, and `make_current()` at the end of
a hand-written blend is exactly what Blend To does when it lands.
