# Block Styles - How To Read Every Row

Every block on an event sheet follows one visual grammar: **icons carry KIND, words carry
MEANING, and the two lanes carry the covenant** - branching on the left, effects on the right.
This page is the field guide: each block style, what it looks like, what it is for, and how it
behaves. Hovering any row always shows the exact GDScript behind it.

![Several styles at once: the identity bars, a state-machine reading with diamond badges, and sentence rows](images/code-patterns-lifted-machine.png)

![The Timeline block and the pattern rows: beats as condition/action child rows, sentences in the action lane](images/pattern-verbs.png)

## The icon legend

The round badges in the icon column are the sheet's alphabet - each is drawn as crisp SVG art
at every zoom:

| Badge | Meaning |
| --- | --- |
| ⟳ (amber) | runs every tick (Every Frame / Every Physics Tick) |
| ▶ (green) | runs once (On Ready and other one-shot triggers) |
| ⌨ | fires from input |
| ➜ | a signal fires (triggers and published signal rows) |
| ◆ (blue) | a state - you are looking at a state machine |
| ƒ | a computed check - this value comes from a function, not a variable |

## Head bars - what this file is, before any event

Above the first event sit the bars that answer "what am I looking at?", each collapsed to one
readable line:

- **The Include bar** names the object (its `class_name`, else its scene's root node, else the
  file) with its class icon and the scene it lives in. On a behavior pack it names the pack and
  its version; on an autoload it wears the globe and says `autoload (global)`. A chip at its end
  says how much of the file reads as events - `96% reads as events · 3 script blocks ▸` - and
  clicking that chip walks the blocks that stayed code, one per click.
- **Folders** hang under it: `Instance variables`, one per `@export_group`, `Triggers this pack
  fires`, and `Global variables used here` on a sheet that touches a project global.
- **The Input head bar** appears on a file that names any control - `this script uses 4 actions -
  jump, move left, move right, fire · Project ▸ Input Map` - with each control's real bindings
  under it, and a ⚠ on one the Input Map does not have.

## Event rows - the workhorse

![Dragging the boundary between the condition and action lanes: the guide line runs the whole sheet, not just the row](images/divider-guide.png)

Two lanes: **conditions left, actions right**. The trigger leads the condition lane with its
tempo badge; more conditions stack below it; actions list down the right. Sub-events indent one
level per nesting - the canvas indent IS the code's tab. Actions read as sentences
("Set variable score to 0", "Add wave[1] to score") and unmatched calls read object, then what it
does ("TreeItem ▸ Set Collapsed ( true )"). Every event is numbered down the left margin, and the
number is what a bookmark, the Find bar and a Doctor finding all print.

## Identity bars - what this sheet IS

![The head at rest: the enum as one sentence, with the Class setup breadcrumb above it](images/prelude-blocks-closed.png)

![The same head opened: one row per enum value with its number, and the Class setup facts listed out](images/prelude-blocks-open.png)

Three definition blocks wear the accent band, a left accent edge, and half again the height of
a content row, so they can never be mistaken for one:

- **Class setup**: the inheritance breadcrumb (`Node ▸ CharacterBody2D ▸ YourClass`) with the
  base class's own editor icon. Open it for the facts as a list - `@tool`, remembered
  variables, setup line count - with the raw prelude lines behind "double-click to edit in
  code". A prelude line carrying an error still surfaces, marker and all.
- **Host binding** (behavior sheets): the host class icon + "Host binding" + the class chip -
  the node this behavior acts on.
- **Enum**: closed, a sentence - "State is one of PATROL, CHASE or FLEE" (long enums say
  "and N more"). Open, one row per value with its number (`PATROL = 0 · default`) and an
  Add value footer. The state list a state machine runs on is a definition, so it gets the bar.

One rhythm across every block that collapses: **a readable line at rest, a list when you lean in**,
one arrow between the two, remembered per row.

## Declare rows - collections as structure

A multi-line dictionary or array declaration is one **Declare** action - a chip header
("Declare waves · Dictionary - 3 entries") with one single-cell row per entry. Entries edit
in place (double-click) or through the Add / Edit / Remove Entry menu; the braces exist only in
the file. Works in function bodies and at file scope (const tables included).

## The switch block - match as rows

A structured `match` never shows code. The event's action lane carries a muted caption
("decides by state · 3 states below"); each case is its own condition/action child row. When
the subject is state-shaped (`state`, `current_state`), cases read as `◆ State: PATROL` rows.
An `if` inside a case body is a CONDITION, so it renders as a nested condition/action child
row - the guard in the condition cell, in plain words (`Can See Player` with the ƒ badge when
the check is computed; `hp < 20` as values), the effect in the action cell. Branching never
appears in the action lane, anywhere.

## The Timeline block - a schedule as rows

"at 0.0s Show Ready · at 1.0s Show GO · at 1.2s Start Round": a muted caption on the event
("timeline · 3 steps") and one child row per beat - the WHEN in the condition cell, the WHAT in
the action cell. Compiles to the await-chain a GDScript author would write; the whole block
suspends, so it lives inside a trigger event (the same rule as Wait). Insert ▸ Timeline adds
one; right-click a beat for "Add Step…".

## Variable rows

One sentence, in this order: **scope word, plain type word, name, value** - `Instance number
speed = 200`, `Constant number MAX_HP = 100`, `Static number spawned = 0` (which adds
`shared by every Player`), `Local text name = ""` inside an event, `Global number Score = 0` on
an autoload, `Field number price = 0` on a Resource script. The type reads in plain words
(number, whole number, text, boolean, vector, color, `list of text`, table, object, scene, any)
with Godot's own spelling one hover away, the value is tinted, and a colour is a live swatch you
can click. Expression defaults show as code, never quoted.

An **Inspector** chip marks the variables a designer can edit; the walrus spelling (`:=`)
round-trips exactly. Right-click for Toggle Constant, Remember Between Runs (persists via
`user://remembered.cfg`), Add setter / Add getter, grouping, and rename-everywhere. A setter
reads as an `➜ On <name> set` trigger under the row and a getter as an expression block.

## Signal rows

The ➜ badge (bright for a published trigger, dimmed for an internal signal), the friendly name,
one field cell per value the signal passes, and the action lane stating the one thing the left
lane hides: `emits state_changed`, or `internal`.

In an opened plain script the row takes the trigger shape instead - `➜ On Died`, `➜ On Hit  body` -
because there every declared signal simply IS one of the file's triggers, with the values it passes
as chips beside it. "internal" names a distinction only a behavior pack has.

## Function blocks - what this sheet can be asked to do

![A pack's published rows: the role badge, one typed chip per input and the gives-back return, with no func signature anywhere](images/define-rows.png)

A function reads as the trigger it is: `ƒ  Functions ▸ On Jump`, with the name and one chip per
input in the CONDITION lane, because that lane answers "when does this run?" and a function's
answer is "when it is called". Its body is ordinary event rows one level in, and the row's tint
says whether it is an action, a condition or an expression. A pack's published function also
carries its category chip - never an annotation wall.

An unpublished helper collapses to one line: `ƒ name(params) → return · function - N lines`, and
the helpers gather under one closed **Helpers** folder. The same ƒ marks computed-check guards,
so the symbol teaches once.

## Comments, regions, groups

Comments are their own full-width rows (Reading Mode restyles body comments as italic intent
captions). Regions collapse a named, colored span of rows. Groups are the chapter bars - taller,
titled, tinted by their color tag, holding events as children.

## Script blocks - the honest escape hatch

Real logic that stays code wears the bright **GDScript** chip and full-strength text - the one
block style that says "this is verbatim code" (an amber ⚠ notes a line the lifter could not
structure, with the reason on hover). Prelude scaffolding never wears the chip: it lives dimmed
under the Class setup bar instead. If a block looks like code and is NOT marked this way,
something is wrong - report it.
