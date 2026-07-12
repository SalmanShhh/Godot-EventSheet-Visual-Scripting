# Player and AI Input - One Seam, Every Behavior

Every input-reading behavior pack in the box can be driven two ways: by the **player**
(keyboard, mouse, gamepad, touch - the default) or by **your sheet's logic / an AI**
(pathfinding, cutscenes, replays, demos, bots) - without changing the pack, the scene, or a
single row of the pack's internals. This page is the whole convention: which packs carry the
seam, how to drive them, and how to put the same seam in your own addons.

## Table of Contents

1. [The idea in 30 seconds](#the-idea-in-30-seconds)
2. [Which packs carry the seam](#which-packs-carry-the-seam)
3. [The three input styles](#the-three-input-styles)
4. [The flagship recipe: AI-driven drag & drop](#the-flagship-recipe-ai-driven-drag--drop)
5. [More recipes](#more-recipes)
6. [Adding the seam to your own addon](#adding-the-seam-to-your-own-addon)

---

## The idea in 30 seconds

Behaviors never hard-wire the keyboard. Each one reads its input through a tiny **intent
seam**: an exported `ai_controlled` bool plus one or two persistent intent variables
(`ai_move_x`, `ai_move_axis`, `ai_throttle_axis`, ...). Off - the default - the pack reads
real input exactly as it always did, byte for byte. On, the pack reads the intent variables
instead, and *anything* can write them: an event row, a pathfinding behavior, a state
machine, a replay file.

The intents are **held, not pulsed**: write `ai_move_x = 1.0` once and the pack keeps moving
right until you change it - exactly like holding a key. Impulse verbs (`jump()`,
`Press Interact`) fire the one-shot parts.

The payoff: the same Platformer Movement node is the player on Monday and a pathfinding
chaser on Tuesday. The same Virtual Cursor is a gamepad cursor in the menu and a bot's hand
in the tutorial. Nothing forks.

## Which packs carry the seam

| Pack | Flip on | Then hold | Impulses |
|---|---|---|---|
| Platformer Movement | `ai_controlled` | `ai_move_axis` (-1..1) | `jump()`, `jump_released()` |
| 8-Direction | `ai_controlled` | `ai_move_x`, `ai_move_y` | - |
| FPS Controller | `ai_controlled` | `ai_move_x`, `ai_move_z` | `jump()` |
| Car | `ai_controlled` | `ai_throttle_axis`, `ai_steer_axis` | - |
| Tile Movement | `ai_controlled` | `ai_move_x`, `ai_move_y` (a held axis steps once per completed step) | Simulate Step |
| Slide Move | `ai_controlled` | `ai_move_x`, `ai_move_y` (dominant axis starts the slide) | `slide("left")` etc. |
| Virtual Cursor | `ai_controlled` | `ai_move_x`, `ai_move_y` | Press / Release Interact, Simulate Mouse |
| Drag & Drop | (always seam-driven) | you feed the drag point every tick - any source | Start Drag / Start Drag At Object / Drop |

The flagship consumers already in the box: **Platformer Pathfinding** drives Platformer
Movement (or 8-Direction, or the FPS Controller) through this exact seam, and **Nav Agent
3D** does the same in 3D. Your sheets get the same privilege - the seam is public.

## The three input styles

1. **Real input (default).** `ai_controlled` off. The pack polls its usual actions
   (`ui_left`...). Rebind through the Input Map as usual - the params dialog's
   `input_action` fields give you a live Input Map picker.
2. **Persistent intents (the AI seam).** Flip `ai_controlled` on, hold the `ai_*` variables
   from rows or code. Best for continuous drivers: chasers, followers, cutscene walks,
   recorded replays. The pack's feel knobs (acceleration, coyote time, drift) all still
   apply - the AI inherits the same movement feel the player has.
3. **One-shot Simulate verbs (Virtual Cursor).** `Simulate Axis` / `Simulate Control` /
   `Simulate Interact` inject a single tick of input and self-clear - handy when your source
   naturally re-fires every tick (following an analog stick you're reading yourself). The
   persistent seam is usually less work.

## The flagship recipe: AI-driven drag & drop

A bot hand that picks up a card and places it on a slot - the exact chain a tutorial's
"ghost hand", an opponent in a card game, or an automated demo needs. Virtual Cursor's
`Simulate Mouse` glides the cursor (through its normal acceleration, so it looks hand-made),
**On Cursor Arrived** fires when the glide lands, and Drag & Drop's
`Start Drag At Object` makes the card follow the cursor node - no per-tick wiring at all:

```
On Ready            -> Hand | Virtual Cursor: Simulate Mouse  card.x, card.y, 0.15

On Cursor Arrived
  Condition: step = 0
    -> Card | Drag & Drop: Start Drag At Object  $Hand, 1
    -> Hand | Virtual Cursor: Simulate Mouse  slot.x, slot.y, 0.15
    -> set step to 1
  Condition: step = 1
    -> Card | Drag & Drop: Drop  0
```

Player-driven is the same scene with zero changes: the cursor reads ui_* actions (or your
gamepad bindings), your rows call Start Drag on **On Interact Pressed** and Drop on
**On Interact Released**, and Snap Positions catch sloppy drops.

## More recipes

- **A patrol car.** `ai_controlled` on, hold `ai_throttle_axis = 1.0`, flip
  `ai_steer_axis` between -1/0/1 at waypoints - the car drives with the same drift physics
  the player gets.
- **A tile-stepping ghost.** Hold `ai_move_x = 1.0` and the Tile Movement pack steps
  cell by cell (one step per completed step, like a held arrow key); react to
  **On Step Finished** to change direction - a Pac-Man ghost in four rows.
- **Demo attract mode.** Record the player's `ai_*` values to an Array with timestamps;
  play them back by writing the same variables - the pack cannot tell the difference.
- **Hand back control.** Set `ai_controlled` false (Pathfinding's Stop Pathfinding does
  this for you and zeroes the intents) - the player's keys work again instantly.

## Adding the seam to your own addon

The recipe is three lines per axis - copy it from any pack above:

```gdscript
## AI drive: read ai_move_x/ai_move_y instead of the arrow keys (a sheet or AI driver flips this on to steer).
@export var ai_controlled: bool = false
var ai_move_x: float = 0.0
var ai_move_y: float = 0.0
```

Then route every input poll through it:

```gdscript
var direction := Vector2(ai_move_x, ai_move_y) if ai_controlled \
		else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
```

The rules that keep the seam trustworthy:

- **Inert by default.** `ai_controlled` defaults to false and the off path is your original
  input read, unchanged. Nobody's game changes because you added the seam.
- **Intents are held state, not calls.** A driver writes them once and your tick keeps
  consuming them - that is what lets a pathfinder, a replay, and a row all drive the same
  pack without knowing each other.
- **Name by role, not device.** `ai_move_axis`, `ai_steer_axis`, `ai_throttle_axis` - a
  reader should know what the number means without opening your tick.
- **Impulses stay verbs.** Jumps, presses, steps are methods (`jump()`), not held floats -
  an edge is an event, not a level.
- **Expose `ai_controlled` in the Inspector** (with a tooltip saying who flips it); keep the
  `ai_*` intent floats unexported - they are wiring, not knobs.

Do this and every AI driver in the box - Platformer Pathfinding today, whatever ships
next - can steer your behavior for free, and so can any user's event sheet.
