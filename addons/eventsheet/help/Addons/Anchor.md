# Anchor - Where a Panel Sits When the Window Resizes

Godot spells a Control's placement as four numbers between 0 and 1 plus four margins. An event
sheet spells it as a **corner**: anchor to the top right, to the centre, to the full rect. This
pack is that sentence. **Anchor To** does the placing, **Set Margins** nudges it in pixels,
**Is Anchored To** asks where it sits, and **On Anchored** fires whenever it moves.

## Where this pack shines

- **A HUD that survives every resolution.** Pin the score to the top right once and forget it.
- **Rows that move panels around.** A pause menu that slides from the centre to the left edge is
  one action, not eight property writes.
- **Reading your own file back.** A hand-written `set_anchors_preset(Control.PRESET_TOP_RIGHT)`
  already reads as *Anchor ▸ Anchor to top right* on the canvas, so the pack and the code agree.

## Setup

1. Attach `AnchorBehavior` as a child of the Control that should be pinned.
2. Pick the corner in the Inspector (`anchored_to`), or write an **Anchor To** row.
3. Leave `follow_resizes` on and the host is placed again every time its parent changes size.

```
On Ready -> Score | Anchor: Anchor To  "top right"
         -> Score | Anchor: Set Margins  -180, 16, -16, 48
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- Set margins **left**, **top**, **right**, **bottom**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Anchor To | `corner` | Puts the host on a corner, an edge, the centre or the whole parent rectangle. |
| Action | Set Margins | `left`, `top`, `right`, `bottom` | The gap in pixels between the host and the corner it is anchored to. |
| Action | Set Keep Size | `enabled` | Whether anchoring keeps the host's current size instead of letting a wide preset stretch it. |
| Action | Set Follow Resizes | `enabled` | Whether the host is placed again every time its parent resizes. |
| Condition | Is Anchored To | `corner` | True while the host sits on that corner. |
| Expression | Anchored Corner | - | The corner word the host is on right now. |
| Trigger | On Anchored | `corner` | Fired every time the host is placed, naming where it went. |

The corner words are `top left`, `top right`, `bottom left`, `bottom right`, `centre`,
`full rect`, `top edge`, `bottom edge`, `left edge` and `right edge`.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `anchored_to` | `top left` | The corner the host is placed on at startup. |
| `keep_size` | `true` | Keeps the host's own size when a wide preset would stretch it. |
| `follow_resizes` | `true` | Re-places the host whenever its parent changes size. |

## Use cases

### 1. A score that never drifts

```
On Ready -> Score | Anchor: Anchor To  "top right"
```

Every resolution, every aspect ratio, one row.

### 2. Health bar across the bottom

```
On Ready -> HealthBar | Anchor: Anchor To  "bottom edge"
         -> HealthBar | Anchor: Set Margins  32, -48, -32, -16
```

The wide preset spans the width; the margins keep it off the very edge.

### 3. A pause menu in the middle

```
On Paused -> PauseMenu | Anchor: Anchor To  "centre"
```

### 4. Full-screen fade layer

```
On Ready -> FadeRect | Anchor: Anchor To  "full rect"
```

A ColorRect anchored to the whole parent covers the screen at any size, so the fade never
leaves a strip uncovered.

### 5. Minimap corner swap

Players who keep walking into the minimap can move it:

```
On Minimap Button -> Minimap | Anchor: Anchor To  "bottom left"
```

### 6. Ask before you move

```
Minimap | Anchor: Is Anchored To  "top right"
  -> Minimap | Anchor: Anchor To  "bottom right"
Else
  -> Minimap | Anchor: Anchor To  "top right"
```

A two-row toggle that reads exactly as it behaves.

### 7. Tool palette down the left

```
On Ready -> Palette | Anchor: Anchor To  "left edge"
         -> Palette | Anchor: Set Keep Size  true
```

Keep Size stops the wide preset from stretching a fixed-width palette.

### 8. Chat log that grows with the window

```
On Ready -> ChatLog | Anchor: Anchor To  "bottom left"
         -> ChatLog | Anchor: Set Margins  16, -240, 400, -16
```

### 9. Portrait and landscape

```
On Window Resized
  Condition: ViewportWidth < ViewportHeight -> Controls | Anchor: Anchor To  "bottom edge"
Else                                        -> Controls | Anchor: Anchor To  "right edge"
```

The on-screen controls follow the phone's orientation without a second scene.

### 10. Toast that pops in the corner

```
On Item Picked Up -> Toast | Anchor: Anchor To  "top left"
                  -> Toast | Fade: Fade in, hold 2, fade out
```

### 11. Boss health across the top

```
On Boss Spawn -> BossBar | Anchor: Anchor To  "top edge"
On Boss Down  -> BossBar | destroy
```

### 12. Splitscreen HUDs

```
On Ready -> P1HUD | Anchor: Anchor To  "top left"
         -> P2HUD | Anchor: Anchor To  "top right"
```

### 13. A tutorial arrow that follows the layout

```
On Step 3 -> Arrow | Anchor: Anchor To  "bottom right"
On Anchored
  Condition: corner = "bottom right" -> Arrow | play "point" animation
```

On Anchored is what lets an effect ride along with the move.

### 14. Pin once and leave it

```
On Ready -> Watermark | Anchor: Set Follow Resizes  false
         -> Watermark | Anchor: Anchor To  "bottom right"
```

Useful when some other row is going to animate the same panel afterwards.

### 15. Settings panel that remembers its side

```
On Load Settings -> Panel | Anchor: Anchor To  saved corner
On Anchored      -> Local Storage | save "panel corner" = corner
```

The expression and the trigger together make the placement a saved preference.

### 16. Debug overlay out of the way

```
On Debug Toggled -> DebugPanel | Anchor: Anchor To  "top left"
                 -> DebugPanel | Anchor: Set Margins  8, 8, 320, 200
```

### Other use cases

**Comic-panel storyboard.** Four Controls anchored to the four corners of a parent make a page layout that reflows at any window size without a single manual position.

**Karaoke lyric line.** The lyric Control anchored to the bottom edge stays readable on a phone held sideways and on a television alike.

**Photo-mode frame.** A border anchored to the full rect draws the frame, while the shutter button rides the bottom right corner.

**Streamer-safe margins.** Anchor the HUD to the corners and then pull every margin inward by a slider, so nothing is hidden under an overlay.

**Accessibility zoom.** When the player scales the UI up, re-anchoring the panels to edges rather than corners keeps everything on screen instead of pushing it off.

## Tips and common mistakes

- **The parent is what places a Control.** This pack listens to the PARENT's resize, so anchoring
  a Control whose parent never changes size looks like it does nothing - it already fits.
- **Keep Size or a wide preset, not both by accident.** `top edge` wants to stretch; leaving
  `keep_size` on keeps the host's width and only moves it. That is usually what a fixed panel wants
  and never what a background wants.
- **Margins are measured from the corner you anchored to.** After anchoring to the right, the left
  and right margins are NEGATIVE numbers - distances back from that edge.
- **A hand-written anchor already reads.** `set_anchors_preset(Control.PRESET_CENTER)` in an opened
  `.gd` shows as *Anchor ▸ Anchor to centre* whether or not this pack is attached; the pack is what
  lets a row WRITE it.
