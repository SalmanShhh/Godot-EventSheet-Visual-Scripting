# Block Styles - How To Read Every Row

Every block on an event sheet follows one visual grammar: **icons carry KIND, words carry
MEANING, and the two lanes carry the covenant** - branching on the left, effects on the right.
This page is the field guide: each block style, what it looks like, what it is for, and how it
behaves. Hovering any row always shows the exact GDScript behind it.

![Several styles at once: the identity bars, a state-machine reading with diamond badges, and sentence rows](images/code-patterns-lifted-machine.png)

![The Timeline block and the pattern verbs: beats as condition/action child rows, sentences in the action lane](images/pattern-verbs.png)

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

## Event rows - the workhorse

Two lanes: **conditions left, actions right**. The trigger leads the condition lane with its
tempo badge; more conditions stack below it; actions list down the right. Sub-events indent one
level per nesting - the canvas indent IS the code's tab. Actions read as sentences
("Set variable score to 0", "Add wave[1] to score") and unmatched calls read Object ▸ Verb
("TreeItem ▸ Set Collapsed ( true )").

## Identity bars - what this sheet IS

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

One rhythm across all fold-bearing blocks: **a readable line at rest, a list when you lean in**,
one fold arrow between the two, remembered per row.

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

`name : type = value` with the value tinted; expression defaults show as code, never quoted.
An `@export` chip marks Inspector-visible variables; the walrus spelling (`:=`) round-trips
exactly. Right-click for Toggle Constant, Remember Between Runs (persists via
`user://remembered.cfg`), grouping, and rename-everywhere.

## Signal rows

The ➜ badge (bright for a published trigger, dimmed for an internal signal), the friendly name,
one field cell per value the signal passes, and the action lane stating the one thing the left
lane hides: `emits state_changed`, or `internal`.

In an opened plain script the row takes the trigger shape instead - `➜ On Died`, `➜ On Hit  body` -
because there every declared signal simply IS one of the file's triggers, with the values it passes
as chips beside it. "internal" names a distinction only a behavior pack has.

## Published verbs (Define rows)

A pack's exposed function reads as a Define row - role badge, friendly name, category chip -
never as an annotation wall. Its body is ordinary event rows one level in.

## Functions and folds

An unexposed helper collapses to one line: `ƒ name(params) → return · function - N lines`.
The same ƒ marks computed-check guards, so the symbol teaches once.

## Comments, regions, groups

Comments are their own full-width rows (Reading Mode restyles body comments as italic intent
captions). Regions fold a named, colored span of rows. Groups are the chapter bars - taller,
titled, tinted by their color tag, holding events as children.

## GDScript blocks - the honest escape hatch

Real logic that stays code wears the bright **GDScript** chip and full-strength text - the one
block style that says "this is verbatim code" (an amber ⚠ notes a line the lifter could not
structure, with the reason on hover). Prelude scaffolding never wears the chip: it lives dimmed
under the Class setup bar instead. If a block looks like code and is NOT marked this way,
something is wrong - report it.
