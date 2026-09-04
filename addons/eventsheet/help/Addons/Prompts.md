# Prompts - The Visible Half Of A Quick-Time Event

The Timed Input rows already do the thinking. They open a window the player has a moment to
answer, say whether the control went down while it was open, grade how close it was, count a
mash, and grade a press against a beat. What they do not do is **show the player anything** -
and a quick-time event nobody can see is a quick-time event nobody can answer.

This pack is the showing: the prompt over the boss's head with the right button on it, the ring
that shrinks while the moment lasts, the flash when it lands, the note that travels a lane to
arrive on the beat. It grades in the same two words those rows do, `"perfect"` and `"good"`,
and adds the third every prompt needs, `"miss"` - so a sheet that already branches on a window
grade needs nothing rewritten to branch on a prompt.

**The glyphs are yours.** Which picture stands for a control on the thing in the player's hands
is a `GlyphSheetResource` the game owns. The device is the one the last input event came from,
so a player who puts the pad down and reaches for the keyboard sees keyboard glyphs on the very
next prompt.

## Where this pack shines

- **A quick-time event in one row.** Prompt `jump` for 0.8 s at the boss, and the glyph, the
  ring, the grade and the two triggers are already there. The alternative is a window row, a
  hand-drawn ring, a label whose text was guessed, and the same again in the next cutscene.
- **"Press E" that is right on a pad.** Glyph For hands the same texture to a HUD hint, a
  tutorial card or a rebinding screen, so the whole game follows the controller the player
  picked up rather than the one the writer had.
- **A rhythm lane in two rows.** Prompt On Beat sends a note down a lane to land on the song's
  next beat, and the Music director is what says when that is.
- **Holds and mashes that read like what they are.** Hold Prompt and Mash Prompt are the same
  moment answered a different way, with the same grade and the same triggers.
- **Sequences without a counter.** Sequence asks for a list of controls one after another and
  fires once at the end with whether all of them landed.
- **Nothing to see is nothing to pay for.** The director parks its own frame whenever no prompt
  is open and no note is on a lane.

## Setup

There is nothing to attach. Prompts registers itself as the **`Prompts`** autoload, the same
shape as Music and Scene Flow, so every sheet reaches it by name with no node path.

1. Register the pack as the `Prompts` autoload (Tools > Register Autoload, or Project Settings >
   Globals).
2. Drag `plain_glyphs.tres` into the director's **Glyphs** slot to see something on the first
   run. It draws flat coloured circles on purpose - it is a starter to replace, not a set to
   use.
3. Ask the player for something:

```
On Boss Grabbed -> Prompts: Prompt  "jump", 0.8, Player
```

4. Branch on the answer:

```
On Prompt Hit     Prompts: Grade Is "perfect" -> Player | Break Free
On Prompt Missed                              -> Player | Take Damage  10
```

That is a whole quick-time event. Everything below is the same four rows in other clothes.

### Making your own glyph sheet

New Resource > **GlyphSheetResource**, save it wherever you keep your UI art, and fill in the
five dictionaries: `keyboard`, `pad`, and the three console layouts. A key is a control name
from your Input Map; a value is the picture of the button it is bound to. A control missing
from the layout in hand falls back to the generic pad and then to the keyboard, so a sheet you
have only half drawn has holes rather than crashes.

### Restyling the prompt and the lane

`prompt.tscn` and `lane.tscn` are **starters**. Copy them into your own project, restyle them,
and point the Prompt Scene property at yours. The director fills in children **by name** rather
than by script, so anything wearing the same names works:

| Child | On | What the director does with it |
|---|---|---|
| `Ring` | the prompt | Writes the time left into its `value`, as a share of its `max_value`. Anything with a value works - a ProgressBar, a TextureProgressBar with your own ring art. |
| `Glyph` | the prompt, and a lane's `Note` | Sets its `texture` to the glyph for the control. |
| `Label` | the prompt | Gets the Input Map's own words when the sheet drew no picture, at the player's text size. |
| `HitLine` | the lane | Where a note has to reach on its moment. A lane without one lands its notes at its own left edge. |
| `Note` | the lane | The hidden child every note is a copy of. The art is the lane's, not this pack's. |

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Prompt **jump** for **0.8** s at *Player*
- Mash **ui_accept** x**12** in **3** s
- Prompt **hit** on the beat in *Lane*

No verb takes a host: every row addresses the `Prompts` autoload by name, and every expression
reads back as `Prompts.<Name>(args)` from any sheet in the project.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Prompt | `action` (String), `seconds` (float), `at` (Node) | Asks the player for a control, for the seconds given, drawn over a node. The glyph is the one for the device in their hands. Answering fires On Prompt Hit with a grade; the seconds running out fires On Prompt Missed. |
| Hold Prompt | `action` (String), `hold` (float), `seconds` (float), `at` (Node) | Asks the player to HOLD a control down for a while, within the seconds given: the winch, the door being forced, the finisher pressed and kept pressed. Letting go resets the hold, because a hold that survived being let go is not a hold. |
| Mash Prompt | `action` (String), `presses` (int), `seconds` (float), `at` (Node) | Asks the player for a number of presses within the seconds given: breaking free of a grab, cranking a handle, shaking off a swarm. It is the shipped mash rows with a prompt over the top. |
| Sequence | `actions` (String), `seconds` (float), `at` (Node) | Asks for several controls one after another, as a comma separated list, each with the same seconds to answer. On Sequence Finished fires once at the end carrying whether every one of them landed; the first miss ends it. |
| Cancel Prompt | (none) | Takes whatever is being asked off the screen with no grade and no miss: the cutscene was skipped, the enemy died first, the player walked away. A sequence cancelled this way finishes uncompleted. |
| Prompt On Beat | `action` (String), `lane` (Node) | Sends a note down a lane to land on the song's next beat, where pressing the control grades it. With a Music director in the project the moment is the song's own next beat; without one it is the Lead Seconds from now, so a lane works on its own too. |
| Force Device | `device_name` (String) | Shows every glyph for one device from now on, whatever the player last touched: the options screen showing a layout on purpose, the tutorial card printed for a console. "auto" hands it back to the last input event. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Prompt Is Open | (none) | True while the player is being asked for something and has not answered or run out yet. |
| Grade Is | `grade` (String) | True when the last prompt to end ended this way: "perfect", "good" or "miss". The same three words a note is graded in, so one branch serves both. |

### Expressions

| Expression | Parameters | Description |
|---|---|---|
| Last Grade | (none) | How the last prompt ended, as a word: "perfect", "good" or "miss". Empty until the first one ends. |
| Prompt Time Left | (none) | Seconds left before the open prompt runs out, and 0 when nothing is open: the fill of a bar drawn somewhere other than on the prompt itself. |
| Sequence Progress | (none) | How far through a sequence the player is, from 0 to 1: the number a progress bar over a cutscene reads. It counts what has been ANSWERED, so it reads 1 on the frame the last control lands. |
| Glyph For | `action` (String) | The picture that stands for a control on the device in the player's hands, straight from your glyph sheet. Put it in a texture anywhere and the whole game follows the pad the player picked up. |
| Device | (none) | Which device the glyphs are being drawn for right now: "keyboard", "pad", or one of the three console layouts. It follows the last input event unless Force Device has fixed it. |

### Triggers

| Trigger | Parameters | Description |
|---|---|---|
| On Prompt Hit | `action` (String), `grade` (String) | Fires when the player answers a prompt in time, carrying the control it was asking for and how well it was answered. |
| On Prompt Missed | `action` (String) | Fires when a prompt runs out with nothing pressed, or when a note goes past its beat unanswered, carrying the control that was missed. |
| On Sequence Finished | `completed` (bool) | Fires once a sequence ends, carrying whether it was completed: true when every prompt in it was answered, false on the first miss or a cancel. |

### The glyph sheet

A **GlyphSheetResource** is which picture stands for which control on which device, written
down. It is an ordinary resource: rename it, duplicate it for a large-print set, share it.

| Property | Default | What it does |
|---|---|---|
| `sheet_name` | empty | What this sheet is called, for your own sake when a project holds more than one. Nothing looks a sheet up by it. |
| `keyboard` | `{}` | Keyboard and mouse pictures, by control name. The last fallback, so a control drawn only here still shows something everywhere. |
| `pad` | `{}` | The generic gamepad pictures, for a pad matching none of the three layouts, and the fallback for a control one of them has not drawn. |
| `xbox` | `{}` | The pictures for a pad whose product name reads as this layout. |
| `playstation` | `{}` | The pictures for a pad whose product name reads as this layout. |
| `nintendo` | `{}` | The pictures for a pad whose product name reads as this layout. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `prompt_scene` | `res://eventsheet_addons/prompts/prompt.tscn` | The scene one prompt is drawn as. Point it at your own copy. |
| `glyphs` | empty | The GlyphSheetResource. Leave it empty and a prompt shows the Input Map's own words instead. |
| `perfect_window_ms` | `80` | How close to a note's own moment a press has to land to grade perfect. |
| `hit_window_ms` | `250` | How far off a note's moment a press may be and still count at all. A note this far past its moment is a miss. |
| `perfect_share` | `0.5` | How much of a timed prompt's window still has to be left for the answer to grade perfect. |
| `lead_seconds` | `1.0` | How long a note travels for when there is no Music director to ask. |
| `flash_strength` | `1.0` | How bright a prompt flashes as it is hit. |
| `flash_seconds` | `0.15` | How long that flash takes to fade. |
| `debug_mode` | `false` | Warns about a prompt scene that cannot be loaded, a lane with no Note child, and a Sequence given no controls. |

## Reading it from expressions

Type `Prompts` in any fx field, or open the fx **Expressions dictionary**, and the pack's five
expressions are listed ready to insert: `Prompts.glyph_for("interact")` for a HUD hint,
`Prompts.prompt_time_left()` for a bar drawn elsewhere, `Prompts.last_grade()` for a score.

## Use cases

### 1. The grab you break out of

The whole quick-time event, in the four rows at the top of this page.

```
On Boss Grabbed -> Prompts: Prompt  "jump", 0.8, Player
On Prompt Hit     Prompts: Grade Is "perfect" -> Player | Break Free
On Prompt Missed                              -> Player | Take Damage  10
```

### 2. A perfect answer that is worth more

The grade is a word, so the reward is an ordinary comparison rather than a second row family.

```
On Prompt Hit  Prompts: Grade Is "perfect" -> Score | Add  250
On Prompt Hit  Prompts: Grade Is "good"    -> Score | Add  100
```

### 3. Forcing a door open

A hold, not a press. Letting go starts it again, which is what makes the player lean on it.

```
On Interact Pressed -> Prompts: Hold Prompt  "interact", 1.5, 5.0, Door
```

### 4. Shaking off the swarm

Twelve presses in three seconds, with the prompt drawn on the player rather than on the enemy.

```
On Swarmed -> Prompts: Mash Prompt  "ui_accept", 12, 3.0, Player
```

### 5. A cutscene with three beats to it

One row for the whole sequence, and one trigger for both endings.

```
On Cutscene Started -> Prompts: Sequence  "ui_left, ui_right, ui_accept", 0.8, Player
On Sequence Finished  completed = true  -> Story | Set Flag  "escaped"
On Sequence Finished  completed = false -> Story | Set Flag  "captured"
```

### 6. Skipping the moment when the enemy dies first

A prompt that is no longer about anything should not be waiting for an answer.

```
On Enemy Died -> Prompts: Cancel Prompt
```

### 7. A rhythm lane driven by the song

The Music director says when the next beat is; the note travels the lane to land on it.

```
On Beat -> Prompts: Prompt On Beat  "hit", Lane
```

### 8. A rhythm lane with no music at all

With no Music autoload the note lands a Lead Seconds from now, so the same row works in a
prototype before there is a soundtrack.

```
Every 0.5 seconds -> Prompts: Prompt On Beat  "hit", Lane
```

### 9. The "Press E" line that is right on a pad

Glyph For is a texture anywhere, so a HUD hint follows the controller rather than the writer.

```
On Interactable Entered -> HintIcon | set texture to Prompts.Glyph For("interact")
                        -> HintLabel | set text to "to open"
```

### 10. A tutorial card printed for one layout

Force Device is the row a menu uses when the screenshot has to show a particular pad.

```
On Layout Chosen -> Prompts: Force Device  LayoutButton.text
On Menu Closed   -> Prompts: Force Device  "auto"
```

### 11. A ring drawn somewhere other than on the prompt

The prompt draws its own ring, but a boss bar at the top of the screen can read the same number.

```
Every tick  Prompts: Prompt Is Open -> BossBar | set value to Prompts.Prompt Time Left()
```

### 12. Slow motion while the moment lasts

The prompt is a moment of tension; the Juice rows are what make it feel like one.

```
On Boss Grabbed -> Juice | Slow Motion  0.4, 0.8
                -> Prompts: Prompt  "jump", 0.8, Player
```

### 13. A miss that costs something specific

The trigger carries the control, so one handler can tell a dodge from a parry.

```
On Prompt Missed  action = "dodge" -> Player | Take Damage  10 of "physical" from Boss
On Prompt Missed  action = "parry" -> Player | Stagger  1.0
```

### 14. A progress bar over a long sequence

Sequence Progress runs 0 to 1 across the whole list, which is exactly the shape a bar wants.

```
Every tick -> SequenceBar | set value to Prompts.Sequence Progress() * 100
```

### 15. A dialogue choice on a timer

The Dialogue Kit shows the line; the prompt is the clock on answering it.

```
On Line Shown  line_has_choice = true -> Prompts: Prompt  "ui_accept", 3.0, ChoicePanel
On Prompt Missed                      -> Dialogue | Choose  "say nothing"
```

### 16. Harder on a higher difficulty

The windows are ordinary properties, so a difficulty screen writes them like any other setting.

```
On Difficulty Chosen  name = "hard" -> Prompts | set perfect_window_ms to 40
                                    -> Prompts | set hit_window_ms to 120
```

### 17. A finisher you have to hold through

A hold with a long window and a short grip is generous; the reverse is not.

```
On Finisher Ready -> Prompts: Hold Prompt  "attack", 0.6, 2.0, Enemy
On Prompt Hit     -> Enemy | Play Animation  "executed"
```

### 18. Two prompts that must not overlap

There is one prompt at a time on purpose - a second Prompt row replaces the first rather than
stacking on it, and a sequence that was running ends uncompleted so nothing waits for ever.

```
On Ambush -> Prompts: Prompt  "dodge", 0.5, Player
```

### 19. Grading against the song by hand

The Timed Input rows are still underneath. Beat Grade takes the Music director's own Next Beat
At, which is the same clock this pack grades on, so the two answers agree.

```
On Punch Pressed -> Set variable  grade = Timed Input.Beat Grade(Music.Next Beat At(), 0.08)
```

### Other use cases

**Lockpicking.** A hold prompt whose window shrinks with the lock's difficulty, and a miss that
breaks the pick, is a whole minigame in three rows.

**Fishing.** Prompt On Beat with no music at all, a lane hidden off screen, and the notes are
the fish tugging - the timing model is the same whether or not anything is drawn.

**Boss phase transitions.** A sequence at each phase change, with the number of controls in it
rising, so the fight gets harder without a single new mechanic.

**Accessibility mode.** Doubling both windows and setting Perfect Share to 0.9 makes every
prompt forgiving without changing one row of the game.

**Controller tutorial.** Force Device around a page of Glyph For textures prints the same
tutorial for every layout the game ships, from one screen.

## Tips and common mistakes

- **The action is a control, not a key.** It is the live Input Map picker, so the prompt follows
  a rebind. A control the project does not have shows its own name on the label, which is what
  somebody looking at a typo needs to see.
- **A prompt with no glyph is not broken.** With no sheet, or with a control the sheet has not
  drawn, the prompt falls back to the Input Map's own words - right on a keyboard, vague on a
  pad. That is the reason to draw a sheet, not a reason to worry on the first run.
- **One prompt at a time.** Asking for a second while a first is open replaces it. Two controls
  at once is a Sequence, and a lane is where several things happen together.
- **The clock keeps running while the game is paused.** The engine clock is what makes a grade
  from this pack and a grade from the Timed Input rows comparable, and it is also why a prompt
  opened just before a pause menu runs out inside it. Cancel Prompt on opening the menu.
- **Milliseconds are for the beat, the share is for the moment.** A timed prompt grades on how
  much of its window was left; a note grades on how far the press was from its moment. Tuning
  the wrong one of those does nothing to the other.
- **A lane needs a Note child.** The notes are copies of it, so a lane without one draws nothing
  and says so in Debug Mode. The grading still happens either way.
- **Reduce Flashing is obeyed, not ignored.** A player who has asked for no flashing gets a
  small slow fade rather than no answer, because the prompt still has to say it landed.

## Already written it by hand? It reads as this pack

A boolean, a deadline and two branches is the shipped Open Input Window pattern, and it still
reads back as those rows exactly as it always did - this pack lands beside them rather than over
them. What it adds is the half that was never rows at all: the scene instanced over the boss,
the texture chosen by guessing the pad, the ring updated in a process event, and the same three
files copied into the next project.

A dictionary mapping action names to textures, indexed by a string somebody set in an if-chain
over `Input.get_joy_name(0)`, is the glyph sheet - written once here, as a file, with the
fallbacks already in it.
