# Variables, Groups and the Sheet Head

Three parts of a sheet are not events: the **head** at the top (the lines your file opens with), the
**variables** under it, and the **groups** and **regions** that hold the events together. This page
is about those three, and about the two dialogs they lean on most - **Compare** and the
**parameters** dialog every row with a blank opens.

Everything here is a reading of real GDScript. A variable row is one declaration; a head band is one
line of the file; a region is two lines of the file. Nothing on this page invents a line, and every
row shown here comes with the code it compiles to, so you can check.

## Table of Contents

1. [The variable sentence](#the-variable-sentence)
2. [Scope words: where a variable lives](#scope-words-where-a-variable-lives)
3. [Globals used here](#globals-used-here)
4. [Static locals: a local that remembers](#static-locals-a-local-that-remembers)
5. [Type words, and the GDScript they write](#type-words-and-the-gdscript-they-write)
6. [The code echo and the View dial](#the-code-echo-and-the-view-dial)
7. [Adding a variable](#adding-a-variable)
8. [Editing a variable row on the canvas](#editing-a-variable-row-on-the-canvas)
9. [Who owns a variable](#who-owns-a-variable)
10. [Asking a question: the comparison rows](#asking-a-question-the-comparison-rows)
11. [The Compare dialog](#the-compare-dialog)
12. [Invert, or, and else](#invert-or-and-else)
13. [Picking with a test](#picking-with-a-test)
14. [The parameters dialog](#the-parameters-dialog)
15. [The sheet head, band by band](#the-sheet-head-band-by-band)
16. [The Sheet Type dialog](#the-sheet-type-dialog)
17. [Groups](#groups)
18. [Regions](#regions)
19. [Tips and common mistakes](#tips-and-common-mistakes)

## The variable sentence

![Six variable rows in the one sentence, each washed lilac with an x badge and its own declaration echoed at the right edge: Instance whole number hp = 100 beside var hp: int = 100, a labelled Movement folder strip holding Instance number speed = 200 with a sliders mark beside @export var speed: float = 200.0 and jump_force under it, then Instance boolean alive = true, Constant whole number MAX_HP = 100 beside const MAX_HP: int = 100, Static whole number spawned = 0 reading shared by every Player, and inside event 1 a Local number dealt = 0](images/variable-sentence-head.png)

Every variable reads the same way wherever it appears - a sheet you authored, a `.gd` you opened, a
behaviour pack, the Manual:

```
<scope>  <type>  <name> = <value>      <description, muted>
```

The spans, left to right:

| Span | What it is |
|---|---|
| gutter | empty on a variable row - only events are numbered |
| `x` badge | the kind cue for a declaration, a 15px outlined mark |
| scope word | Global, Instance, Local, Constant, Static, Field or Shared, in the theme's lilac |
| type word | number, whole number, text, boolean, vector, color, list, table, object, scene, any |
| name | bold |
| sliders mark | only when the value is editable in the Inspector. Hover: "Editable in the Inspector" |
| `=` and the value | the value edits in place |
| description | muted, on the same line; it ellipsises first when the row is tight |
| code echo | the exact declaration the compiler writes, at the right edge |

So four declarations of a player script read as four rows:

| The row | The line it compiles to |
|---|---|
| `x` Instance whole number **hp** = 100 | `var hp: int = 100` |
| `x` Instance number **speed** = 200 (sliders) Pixels per second. | `@export var speed: float = 200.0` |
| `x` Instance boolean **alive** = true | `var alive: bool = true` |
| `x` Constant whole number **MAX_HP** = 100 | `const MAX_HP: int = 100` |

Two things a reader coming from the older look should know:

- **Scope and type are words, not pills.** The `const` and `static` badges folded INTO the scope
  word: a `const` reads "Constant", a `static var` reads "Static". The only boxes a variable row
  wears now are the `x` kind badge and the sliders mark.
- **`name : Type = value` is gone from the canvas.** That spelling survives where it belongs - on
  the name's hover, and in the code panel under the rows.

A flat lilac wash and a 2px rule down the left edge mark every variable row, so a declaration is
recognisable before a word of it is read. Three theme colours dress it (`variable_row_wash_color`,
`variable_row_rule_color`, and `variable_row_wash_end_color` for a theme that wants the wash to fade
across the row - every bundled preset ships it equal to the wash, which is what keeps them flat).

**The order is the order you wrote them in.** The view does not sort. Drag one declaration past
another and the drop WRITES the new order into the file; **Sort A-Z** on the row's right-click menu
writes alphabetical when you ask for it. Variables never fold as a block: the only fold in the list
is a folder you made yourself, an Inspector group, which draws as a slim labelled strip over its
rows with the rows left exactly where they were.

**A folder is a folder wherever the variables live.** An `@export_group("Movement")` in a `.gd` you
opened wears the same labelled strip, over the run of members declared under it - and, exactly as in
the Inspector, the group stays in force for every member after the line that opens it, not only the
first. The rows keep their indent: a folder never pushes what it holds sideways, and the file
re-emits byte for byte, because the strip is a reading rather than a line.

## Scope words: where a variable lives

The scope is **derived**, never stored. Nothing in your sheet records "this is a Global"; the sheet
looks at what the declaration is and at what the file is, and says the word.

| Scope word | What it means | What it is derived from |
|---|---|---|
| Global | One value the whole project shares. | a member of an autoload's script |
| Instance | One per object - each copy in the scene has its own. | a member of an ordinary node script |
| Local | Lives inside the event or function it sits in. | a declaration inside an event body |
| Static local | Only this event reads it, and it keeps its value between runs. | a Local row with **Static local** ticked |
| Constant | Never changes once the game runs. | `const` |
| Static | One value shared by every copy of this object. | `static var` |
| Field | Saved in every resource made from this - a data field, not a live value. | a member of a script extending `Resource` |
| Shared | One for the whole editor, kept between sheets. | a `static var` on a class nothing is instanced of |

Those one-liners are the hover on the scope word, and the same lines the Add variable dialog puts
under each choice.

**A global reads as its owner.** A row that reaches into an autoload reads with the autoload's name
in the object column and the bare name in the sentence; the `Game.` prefix is dropped from the name
and kept where it is real code - inside expressions, and in the echo:

| The row | The line it stands for |
|---|---|
| `x` Global number **Score** = 0 (from Game) | `Game.Score` |

That echo is deliberately a reference and not a declaration: the declaration lives on the autoload's
own sheet, and echoing it here would claim a line this file does not have.

## Globals used here

A global is declared once, on an autoload, and read everywhere. So the sheet that reads one **shows
it where it is used**: at the very top, above the variables the sheet declares itself, one row per
`Game.X` the sheet names anywhere - in a parameter, in an expression, or in a script block.

```
x  Global  number  Score = 0     from Game            Game.Score
x  Global  boolean Muted = false from Game            Game.Muted
--------------------------------------------------------------- the hairline
x  Instance whole number hp = 100                     var hp: int = 100
```

The hairline under the last of them is the whole point of the block: above it is what this file
**borrows**, below it what this file **owns**.

- **Both spellings of a use are found.** A hand-written or typed `Game.Score` is one string; a row
  you PICKED files the object and the property in separate cells, and there is no `Game.Score`
  anywhere in it. The second shape is paired only when the autoload really declares that name, so a
  value cell reading `0`, or one naming a variable of this sheet, is never mistaken for a global.
- **The type and the value come from the autoload's own script**, read straight off the file - so a
  global reads the same here as it does where it lives, and a name the autoload does not declare
  reads with no type and no value rather than with an invented one.
- **The echo is a reference, not a declaration**: `Game.Score` is the form you would type in THIS
  sheet. The `var Score: int = 0` line belongs to the autoload's own sheet.
- **Editing one opens the autoload sheet**, because that is the only place the declaration can
  change. Nothing on these rows edits in place, and none of them is added to your sheet: they are a
  reading, so the file re-emits exactly as it was.
- **Two places never show them.** The autoload that declares them (its own globals are already its
  rows), and a read-only preview, whose head gathers the same list into one `Global variables used
  here` folder instead.

## Static locals: a local that remembers

A **Local** is made when its event runs and gone when the event ends - which is exactly what you want
for a working total, and exactly what you do not want for a hit counter. Tick **Static local** in the
Add variable dialog (offered for the Local scope, and only there) and the row keeps its place under
the event while the value survives from one run of that event to the next:

| The row | The lines it stands for |
|---|---|
| `x` Static local whole number **hits_taken** = 0 | `var _hits_taken := 0` at class level, and `_hits_taken` wherever the event names it |

GDScript has no `static` inside a function, so there is nowhere narrower to keep such a value than
the class. The compiler hoists the declaration to a private member - the leading underscore is what
"nothing outside this event should reach for it" looks like in Godot code - and rewrites the event's
uses onto it. Words inside a printed sentence are left exactly as written: `print("hits: ", hits_taken)`
compiles to `print("hits: ", _hits_taken)`, the sentence untouched and the value read from the member.

A `# @static_local:hits_taken` comment above the member says which row it belongs to. That marker is
what lets the file open as the row again: reopen the `.gd` and the member comes back as a Static local
row, and saving it untouched reproduces the file byte for byte. A private member somebody wrote by
hand, with no marker, stays what it always was - an ordinary variable row.

Two rules the sheet holds you to:

- **The tick is offered for the Local scope only.** A member variable wears *Static* instead (one
  value for every copy of the object); a local can never be a `static var`, so the two are never on
  screen together.
- **One event owns the name.** Two events each declaring `hits_taken` would hoist to the same
  `_hits_taken`, so the sheet declares it once and says so in a compile warning rather than writing a
  file that will not parse.

**Moving a local.** Drag a Local row onto another event and it re-scopes there - the declaration
moves, and nothing else does. Drag it onto the sheet head and it is promoted: the Add variable dialog
opens on Instance with everything the local already said filled in, so what you confirm is the new
sentence, and the local is dropped only once you do.

## Type words, and the GDScript they write

| Type word | GDScript | Example value |
|---|---|---|
| number | `float` | `200.0` |
| whole number | `int` | `100` |
| text | `String` | `"hello"` |
| boolean | `bool` | `true` |
| vector | `Vector2` | `Vector2(0, 0)` |
| color | `Color` | `Color("#ff9b3c")` |
| list | `Array` | `[]` |
| table | `Dictionary` | `{}` |
| object | `Node` | `null` |
| scene | `PackedScene` | `null` |
| any | `Variant` | anything |

A declared `int` reads "whole number" because the author said they wanted no fractions; an
undeclared `100` still reads "number". A number the file spelled with a decimal keeps it, so
`200.0` reads `200.0` and the row never lies about the literal.

A colour is always a live swatch: `var tint := Color.WHITE` reads `Instance color tint =` swatch
`white  #ffffff`, and a colour nobody has a word for reads its hex. Picking a new one writes it back
in the spelling the line already used, so a `Color.RED` stays a named constant and a
`Color(1, 0.6, 0.2)` stays numbers.

## The code echo and the View dial

At the right edge of every variable row, muted, sits **the exact line the compiler emits for that
row**. It is the emitter's own string, not a second formatter, so it cannot drift from the file.

It is coloured by a small tokeniser over eight classes - keyword, annotation, type, member, number,
string, symbol, comment - whose colours are read from your Editor Settings
(`text_editor/theme/highlighting/*`), with the sheet theme as the fallback. So it matches whatever
GDScript theme you already read code in.

- It sits at about 60% strength and comes up to full on the row under the pointer.
- It is dropped entirely on a canvas narrower than about 440px, rather than squeezing the sentence.
- Activating it opens the code panel at that line.

**View ▸ Variable rows** dials how much of the row is drawn:

| Setting | What a row looks like |
|---|---|
| sentence | `x` Instance number **speed** = 200  Pixels per second. |
| both (the default) | `x` Instance number **speed** = 200 ... `@export var speed: float = 200.0` |
| code | `x` `@export var speed: float = 200.0` |

In **code** the row IS the line: the sentence spans step aside, the echo comes up to full strength,
and the badge, the wash, the drag, the rename and the dialog are all unchanged. It is a toolbar
setting, never a row on the sheet. Simple Mode pins it to **sentence**.

## Adding a variable

**How you get there.** Right-click the canvas and pick **Add Variable ▸ Global variable… /
Local variable… / Instance variable…** - "add a variable" is really three questions, and the submenu
asks the one that matters. Double-clicking a variable row, or **Edit Variable** on its menu, opens
the same dialog titled *Edit variable*. With a group head selected, `V` adds one of that group's own
locals.

The dialog asks for the row in the order the row reads:

| Field | What it is |
|---|---|
| (a line at the top) | whose variable this is - "to Player" |
| **Scope** | a dropdown: Instance, Local, Global, Constant, Static, each with its one line under it |
| **Write into** | which autoload a Global lands on. Shown only for Global |
| **Name** | Enter confirms. A name already taken here is flagged under the field as you type |
| **Type** | Number, Text, Boolean, a divider, then Vector, Color, List, Table, then the Godot types under their own names. The GDScript spelling sits muted beside the field |
| **Whole numbers only** | the tick that turns Number into `int` |
| **Initial value** | the value the variable starts at |
| **Description** | the muted tail of the row, and the `##` comment above the line |
| **Flags** | Static and Constant, as ticks |
| **On ready** | for a value fetched once the scene is ready, like `$Player` |
| **More options (Inspector, range, drawer, group…)** | the Inspector polish, collapsed |

At the foot there is **one help strip**, and it describes whatever is focused - never a hint per
field, all shown at once. Open the Type list and it describes each type as you arrow down it, before
you pick one. The strip has four parts:

- a heading naming the focused thing ("Scope · Instance"),
- a paragraph,
- **READS AS** - the row you will get, composed the same way the canvas composes it,
- **IN CODE** - the compiler's own emitted declaration for those answers.

Because IN CODE is produced by the emitter, the dialog cannot promise a line the compiled sheet
would not write.

Three gates worth knowing:

- **Global** reveals *Write into* and confirms straight into that autoload, in one undo step.
- **Local** greys the Inspector tick - a local is never a property - and offers *Static local*,
  the one flag a local can wear.
- **Constant** greys Static with it - GDScript has no `static const`.

A fresh variable opens on the scope the last one used, so a run of instance variables answers the
scope question once rather than five times. An **edit** never moves a variable's scope behind your
back: it opens on the scope the variable has.

## Editing a variable row on the canvas

| Gesture | What happens |
|---|---|
| double-click the value | edits in place, with the type word as the guide rail. A literal the type cannot hold turns amber and is refused |
| double-click anywhere else on the row | opens the Edit variable dialog |
| double-click the echo | opens the code panel at that line |
| **F2** | renames the variable in place, with the count of what committing will rewrite beside the field ("renames 6 uses in 2 sheets · Enter to apply · Esc"). Enter is the full Rename Everywhere in one undo step; Esc leaves the file alone |
| hover the name | every other use of it in the same scope lights up, so you can see what reads it |
| Alt+Up / Alt+Down | reorders the declaration, writing the new order |
| drag the row onto another declaration | reorders it, or folds both into one Inspector folder; the drop writes it |
| drag the row onto a parameter's value | fills that parameter with the spelling it needs - bare for this object's own variable or a local, `Game.Score` for a global |

While the game runs, **Live Values** adds a green `now 73` chip after the initial value - after it,
not instead of it, so the declaration still reads as a declaration.

The right-click menu on a variable row:

| Item | What it does |
|---|---|
| Edit Variable | the dialog above |
| Rename Everywhere… (**F2**) | renames the declaration and every use, in one undo step. The key does it in place on the row |
| Change Type Everywhere… | retypes it and rewrites every row that sets or compares it |
| Convert Scope | moves it between Global, Local and Instance |
| Toggle Constant | `var` to `const` and back |
| Remember Between Runs | keeps its value between plays (the head grows a *remember* band) |
| Group Under a Heading… | the Inspector folder strip |
| Sort A-Z | writes alphabetical order |
| Copy as Expression | puts the name a field or a hand-written line needs on the clipboard - a global as `Game.Score`, which is the spelling that runs |
| Show in Inspector | one tick that adds or removes the `@export` |
| Add setter / Add getter | the two accessor events |
| Export / Import Grid, Export / Import Translations | the spreadsheet and translator round trips, on the variables that have a table |

## Who owns a variable

The object column of a row names **the object that HAS the variable**, because that is what a reader
looks for:

| Row | Object column | Why |
|---|---|---|
| Subtract 10 from `hp` | Player | `hp` is an instance variable of this sheet's object |
| Set `Game.Score` to 0 | Game | the variable belongs to the autoload |
| Set the event's own `combo` to 0 | System | a local belongs to the event it sits in, and to nothing you can select |

Only the label moved. No `ace_id`, no template and no emitted line changed.

Everything that lists variables lists them by owner, in the same order - this object first, then the
globals, then the locals in view:

- **The picker's Variables group** offers the verbs in the order you reach for them - Set value, Add
  to, Subtract from, Set boolean, Toggle boolean, then the two questions, Compare variable and Is
  boolean set - and each verb names the variables it can take ("Add to · hp, speed"). A verb with
  nothing of that kind in scope says "nothing of that kind yet" before you click it.
- **The expression picker** groups the same way, shows each entry's type word and what it starts at,
  greys an entry whose type cannot go where the parameter is asking, and says under the tree exactly
  what picking it inserts ("Inserts Game.Score").
- **The Anatomy rail** reads "Instance, of Player", "Globals used here, from Game" and "Locals in
  view", each line composed by the same call the rows make.
- **The Inspector** carries **Instance variables · N** beside *Edit Event Sheet*, opening the same
  table the sheet has, with a muted line under it naming the variables that are NOT in the Inspector.

The two boolean verbs complete the family: **Set boolean** writes `{var_name} = {value}` with true
and false already in the list, and **Is boolean set** asks `{var_name}` plainly instead of comparing
against `== true`. Both write exactly the GDScript the older rows write.

**A name the sheet does not have says so in place.** A row naming `hpp` grows a red note under its
event - "hpp is not a variable of Player. Did you mean hp?" - with a **Use hp** button that renames
every use of it in one undo step. A verb handed the wrong KIND of variable grows an amber note
instead ("nickname is text - Add to wants a number. Set value fits."), because that line compiles and
only misbehaves - and it carries a **Change to Set value** button that swaps the verb for the one
that fits, carrying what was typed across to whatever the new verb calls it.

## Asking a question: the comparison rows

A comparison row shows the symbol a reader means, and the file keeps the spelling GDScript needs:

| Operator | The row shows | The file has |
|---|---|---|
| equal to | `=` | `==` |
| not equal to | `≠` | `!=` |
| less than | `<` | `<` |
| at most | `≤` | `<=` |
| greater than | `>` | `>` |
| at least | `≥` | `>=` |

Equality reads as a single `=` because a sheet row is a question, not an assignment - there is
nothing for the doubled character to disambiguate. So a row reads `hp ≤ 0` and the compiled file
says:

```gdscript
if hp <= 0:
	alive = false
```

Every operator dropdown in the plugin resolves through one list, and that list now leads with the
symbol and says it in words after: `=  equal to`, `≠  not equal to`, `<  less than`, `≤  at most`,
`>  greater than`, `≥  at least`. The token that is actually inserted sits muted beside the choice,
so the friendly wording teaches the spelling instead of hiding it.

## The Compare dialog

**How you get there.** Pick any comparison from the picker (Compare variable, Compare Values, Is
Between Values, Is Outside Range, Values Are Near, or one of the text tests), or edit a comparison
row that is already on the sheet. All of them open the one **Compare** dialog.

The picker files them the way the dialog treats them: **Compare variable** sits in the Variables
group beside Set value and Is boolean set, because comparing a variable is the question that group
is for, and the other eleven live together under **Variables ▸ All comparisons**. Every one of the
twelve is still registered under its own name, so typing "begins with" or "within" finds that row
directly.

It asks the three things a comparison actually decides:

| Box | What it takes |
|---|---|
| **Compare** | any variable this sheet can name - its own, the globals it reads and the locals in scope - each with its type word and what it starts at, or *Something else…*, which turns the box into free text for any expression. Picking a global writes the `Game.Score` spelling the expression needs |
| **Is** | the operator list, with a **ranges** group at the foot |
| **To** | what to compare against |
| **And** | the other end of a range. Shown for between / not between |
| **Give or take** | how far apart two values may be and still count as equal. Shown for within ± |

Plus two ticks: **Ignore case** (text only) and **Invert - true when it is NOT the case**.

The operator you pick decides which existing condition the row becomes. No id changed and no
template changed; the mapping is the whole feature:

| You pick | The row becomes | It compiles to |
|---|---|---|
| one of the six, on a variable | Compare variable | `hp <= 0` |
| one of the six, on a typed expression | Compare Values | `score + 1 > 10` |
| between   two values | Is Between Values | `(1 <= hp and hp <= 50)` |
| not between | Is Outside Range | `(hp < 1 or hp > 50)` |
| within ±   of a value | Values Are Near | `absf(a - b) <= 0.01` |

When the left side is **text**, the operator list becomes the words text uses - is, is not, begins
with, ends with, contains, is one of, matches, is empty - and each writes the text condition that
already exists for it (`.begins_with()`, `.contains()`, `in [...]`, `.match()`, `.is_empty()`).
Ticking **Ignore case** writes `to_lower()` on both sides, which is what a hand-written check does.

The one help strip at the foot describes whatever is focused and carries both readings: **READS AS**
(the row you will get) and **IN CODE** (the line the compiler will write). The code line is produced
by handing a throwaway condition to the compiler, so the dialog cannot promise a spelling the
emitter would not use.

Editing a comparison row reopens it in the same dialog, so turning `hp ≤ 0` into `hp between 1 and
50` is one edit rather than a delete and a re-pick.

## Invert, or, and else

**Inverting flips the question when there is a clean opposite.** A condition marked Invert used to
compile to `not (hp <= 0)` and wear a mark you had to unwrap. All six comparison operators have a
clean opposite, so the row simply says - and emits - the opposite:

| You wrote | The row reads | The file has |
|---|---|---|
| `hp ≤ 0`, inverted | `hp > 0` | `if hp > 0:` |
| `state = "idle"`, inverted | `state ≠ "idle"` | `if state != "idle":` |

Same truth table, one fewer pair of brackets. Both spellings still open as sheets: a hand-written
`not (hp <= 0)` lifts as a row of its own that reads `not (hp ≤ 0)`, so your file re-emits byte for
byte either way.

A condition with **no** clean opposite - begins with, is on floor - is unchanged except for its
mark, which is now the word **not** in the badge column rather than a symbol.

**An OR block says "or".** Two conditions that are OR'd are separated by a small ruled `or` drawn
between them, in place of the badge every condition after the first used to wear. "or" is what sits
between two questions, not a property of one. Right-clicking an event still toggles AND / OR.

**An Else says what it follows.** An Else row carries "neither of 9" - the number of the event its
chain starts at - because an Else several sub-events below its `if` is the classic reading mistake.

## Picking with a test

A For Each over a group that also narrows reads as the pick it is, with the family in the object
column:

| # | Conditions | Actions |
|---|---|---|
| 12 | Enemy · Pick where hp < 10 · nearest to Player first · top 3 | Enemy · Destroy |

A plain walk over everything is still a For each. This is display only: the loop compiles exactly
as it did.

## The parameters dialog

**How you get there.** Any action or condition with a blank in it - picked from the picker, or a row
whose cell you clicked.

- **The title IS the row.** Not "Subtract from Parameters" but **Player   Subtract damage \* 2 from
  hp** - the object the row belongs to, then the sentence with your values filled in live as you
  type, in the sheet's own colours. The verb's name sits muted at the right, where it belongs once
  the sentence is doing the talking.
- **One help strip at the foot, for the focused parameter only.** The per-field descriptions and the
  tooltips repeating them are gone. The strip says what the parameter is for, then what THIS KIND of
  box takes, then **IN CODE**: the line the compiler will write for the values as typed. Tab to the
  next field and the text is replaced, never stacked, so a four-parameter dialog reads as four rows.

The "what this kind of box takes" paragraph comes from a table keyed on the parameter's hint. A few
of them:

| Hint | What the strip says |
|---|---|
| `expression` | a number, a variable or an expression, and what is in scope |
| `variable_reference` | one of this object's variables, with its type and (while the game runs) its value |
| `color` | a colour word, a hex, or `Color(1, 0.3, 0.3)` |
| `input_action` | an action from the project's Input Map, with the keys bound to it |
| `group_reference` | a node group, with how many nodes of the open scene are in each |
| `scene_node` | a node in the open scene - drag it in from the Scene dock |
| `angle` | degrees, measured from pointing right and turning clockwise |
| `minutes_seconds` | a length of time, as `3:00` or as plain seconds |

**A choice explains itself, from wherever the choice came from.** An Input Map action reads with the
keys bound to it (`jump    Space - Gamepad A`); a node group with how many nodes of the open scene
are in it (`enemies    14 nodes in this scene`, or `none yet - added at runtime?`); a variable with
its type word and what it starts at; a true/false pair with the token it stands for. A pack's own
list can carry a line per option by declaring `note` beside `key` and `label`.

**Validation happens at keystroke time, in the strip.** Two tones, and OK stays where it is with the
reason beside it rather than going grey without explanation:

| Tone | When | What you get |
|---|---|---|
| red | a required field left blank | "Amount cannot be left blank - the row has nothing to write." |
| red | a name that is not a variable | "hpp is not a variable of Player. Did you mean hp?" plus a **Use hp** button and an **Add hpp…** button that opens the Add variable dialog on that very name |
| amber | a literal of the wrong kind | "\"ten\" is text. This needs a number. If you meant to join text, Set value can." |

Coming back from **Add hpp…**, the list has it: the dialog re-reads its catalog when it regains
focus.

**And when nothing is wrong, the strip can still offer a plainer reading.** A **Set value** whose
expression only adds to (or subtracts from) the very variable it is setting - `hp = hp + 1` - offers
**read as Add to**; `hp = hp - damage * 2` offers **read as Subtract from**. One press rewrites the
row as that verb, in one undo step, and the compiled line does not change. The offer is withheld
whenever taking it would change what the row computes (`hp - a + b` is not `hp -= a + b`) or when
the expression is somebody else's arithmetic.

## The sheet head, band by band

The head is the top of the sheet, and it is **the head of your file**: one band per line the file
opens with, in reading order. Nothing folds. One fact, one control and one code echo per band.

| Band | What the row shows | The line it stands for | Its control |
|---|---|---|---|
| name | `Player`, bold, wearing the base class's editor icon | `class_name Player` | F2 or double-click renames the class everywhere |
| extends | `CharacterBody2D` | `extends CharacterBody2D` | `change…` opens the host picker |
| @icon | the swatch and the path | `@icon("res://icons/player.svg")` | `change…` opens an image file dialog |
| @tool | "runs in the editor too" | `@tool` | a switch |
| ## | the description | `## The player avatar: movement and health.` | edits in place; Enter commits |
| autoload | the singleton name, `Game` | `project.godot: autoload/Game = "*res://game.gd"` | `Project Settings…` |
| host | "acts on its parent" | `var host: Node2D · _enter_tree: host = get_parent()` | (none - it comes from the kind) |
| remember | "high_score, unlocked kept between runs" | `@onready var __ef_remember_boot: bool = _ef_recall_remembered()` | (the row menu's Remember Between Runs) |
| include | the included sheets, by file name | (no line - an include is merged at compile time) | `open` |

Under the stack sits a muted **+ add** row offering only the lines this sheet could have and does
not: `+ add: icon · @tool · description`. Never autoload and never host - those come from choosing a
kind, not from adding a line.

Three details the head is careful about:

- **Every band matches a real line, and nothing invents one.** An autoload usually has no
  `class_name` at all, so its name band shows the file name muted and echoes
  `# no class_name - the name is the autoload entry`. The include band ships with no echo, because
  an include produces no line of the file.
- **A `@tool` a kind usually carries and this file does not** still shows, with its switch off and
  the echo ghosted, so the control stays findable exactly where it is most often missing. Every
  other sheet is offered it under **+ add**.
- **Renaming says what it will touch first.** F2 on the name band shows "renames 9 uses in 4 sheets"
  before it writes anything.
- **An opened file wears the same stack.** A behaviour pack or any `.gd` opened as a read-only
  preview is not given a second kind of head: it gets these bands, and the Include bar under them
  carries only what no band states - that it is an addon pack, its version, the class it behaves on,
  how much of it read as events, which file it is. Nothing on the head is said twice.

**A new sheet's bands ask their questions.** The name band reads `Untitled · name it`, the extends
band `Node · choose what it extends`, and an `attach to a node` prompt row sits under them. Each
prompt is a muted link, not a wizard, and each disappears as it is answered.

## The Sheet Type dialog

**How you get there.** **Sheet ▸ Sheet Type…**, or making a new sheet.

**Kind** is a dropdown and it comes first: the six kinds most sheets are, then a divider, then the
kinds that make editor tooling. Each is described in the one help strip at the foot. Then **Name**,
**Extends**, **Icon**, **Description**, **Runs in the editor too**, and **More (tags, includes,
uses, requires)** for the composition fields.

This is the one dialog whose strip has **no READS AS line**: the head above it IS the preview. Every
type still carries its frozen index as its item id, so a saved sheet's kind is unchanged however the
list is ordered.

## Groups

A group is a folder you drew around rows. It is one row on the sheet:

| Span | What it is |
|---|---|
| folder mark | in the badge column |
| title | bold, inline-editable |
| description | muted, right beside the title, also inline-editable |
| counts | at the right edge: "3 events · 1 local" |
| ring | before the switch, when the group can be switched at runtime |
| switch | `◍` active on start, `◌` not. One click throws it |

A folded head keeps the description and adds what is inside it, including the objects the group
touches - which is the sentence you need to decide whether to open it.

**The body wears a bracket, and the rows do not move.** A 2px rule in the group's own colour runs
down the LEFT EDGE of the body, from the head's bottom to its last row's bottom. Nested groups inset
one step each, so where a group ends is visible without counting indents, and nothing is pushed
sideways to make room for it. A group switched off fades its whole body.

**How you get there.** `G` with rows selected groups THEM and opens the name editor; `G` with
nothing selected adds an empty group at the cursor. `Ctrl+Shift+G` opens all groups, or closes them
all when any is open.

The group's menu:

| Item | What it does |
|---|---|
| Edit Group… | name, description, Active on start, Can be switched at runtime, and Colour, in one dialog with the one help strip. The swatch has to open on some colour, so it is written only when you move it - a group that carries none stays uncoloured |
| Active On Start | the tick, without opening the dialog |
| Open / Close Group | fold this one |
| Open All / Close All Groups | `Ctrl+Shift+G` |
| Add Local Variable… | `V` with the head selected does the same |
| Group Color… | paints the bracket, the badge and the head's left rule |
| Turn Into Region | with the reason in the item itself when it cannot |
| Ungroup - Keep The Rows | drops the folder, keeps everything in it |

**A group's own variables are rows.** Its local variables render as Local rows at the top of its
body, in the same one sentence, each echoing the `var` line the compiler writes for it.

**Set Group Active picks the group from a list.** The two group rows keep their ids, their templates
and the exact code they emit; their Group field offers this sheet's own groups (switchable ones
first) written as the token the compiler addresses, with a one-click offer to make a group
switchable when the row names one that is not. They read "Set group Tutorial inactive" and "Group
Tutorial is active", and a runtime-switchable group compiles to a plain member and a guard:

```gdscript
var __group_juice_active: bool = true
```

```gdscript
	# @group:juice
	if __group_juice_active and __every_beat_caro >= maxf(0.5, 0.001):
		beat += 1
```

The group itself is one class-scope annotation line, which is how it survives the round trip:

```gdscript
## @ace_group(uid="juice", name="Juice", toggleable=true)
```

**Scrolled inside a group**, what pins at the top of the canvas is that group's own head - title,
description, counts and switch - so it can be folded, switched off or edited without scrolling back
up. The parent chain shortens to the last two names, and the whole chain is the hover.

## Regions

A region is the script editor's own fold mark, `#region` / `#endregion`, and it now looks like one
rather than borrowing the group bar.

| Row | What it shows |
|---|---|
| opening fence | a **dashed** `#` badge, the name in bold, the description muted beside it, and the real line echoed at the right edge: `#region Movement` |
| the body | a **dashed** 2px rule down the left edge in the region's own colour - the dashed twin of a group's solid bracket. No row is pushed sideways |
| closing fence | a slim tick whose only text is `#endregion`. The old "end region" prose is gone |
| folded opener | how much it holds, and both fences at once: `#region Movement … #endregion` |

So a region in the file is exactly a region on the sheet:

```gdscript
#region Movement
func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis("ui_left", "ui_right") * speed
	move_and_slide()
#endregion
```

The region menu is only what two lines of a file can do - no locals, no on/off switch, no ungroup:

| Item | What it does |
|---|---|
| Rename Region… | also F2 |
| Open / Close Region | fold this one |
| Open All / Close All Regions | every region on the sheet |
| Turn Into Group | wraps the fenced rows in a group and drops both fences |
| Region Color… | a fence stores its colour as the `#rrggbb` its marker line carries |
| Remove Region - Keep The Rows | drops both fences, keeps everything between them |

**Regions and groups trade places.** *Turn Into Group* on an opening fence wraps the fenced rows in
a group, carrying the name, description and colour across; *Turn Into Region* on a group head does
the reverse. One undo step each, nothing inside moves, and the round trip is byte-identical. A group
that a region could not carry says so **in the menu item itself** - "Turn Into Region - has 2
locals" - and is greyed. The three refusals are locals, a runtime switch, and a group that is
switched off (a disabled group compiles out and a region cannot, so converting would silently change
what compiles).

**An unmatched fence says so, with the fix on the row.** An opener with no closer gets an amber note
directly under it - "Debug helpers never closes, so it cannot fold. Add #endregion after the last
row you want inside." - carrying a **Close after row N** button that writes the missing fence after
the last row before the next group or fence. A closer with no opener says "#endregion closes nothing
- there is no #region above it. Remove it, or open a region first." Amber, never red: the file still
compiles.

**A block kind can ask for that look.** `EventSheetBlockKind.row_style(entry)` returns `"section"`
(the default flat block row), `"group"` or `"region"`, so a kind of your own that stands for
STRUCTURE gets a shape the sheet already has, through a public path rather than a special case in
the renderer.

## Tips and common mistakes

- **The scope word is derived, so change the declaration, not a setting.** There is no "make this
  global" field on a variable row - a variable is Global because it lives on an autoload. *Convert
  Scope* on the row menu is the gesture that moves it.
- **A global's name is bare on the row and qualified in an expression.** The row says `Score`; a
  parameter field needs `Game.Score`. *Copy as Expression* hands you the spelling that runs.
- **"Initial value", not "default".** It is the value the variable starts at. Godot's word "default"
  means something else, and the dialog stopped borrowing it.
- **A `≤` on the row is a `<=` in the file.** The symbols are how the row reads; the two-character
  forms are what the templates insert and what the compiler emits. Nothing to convert.
- **Inverting a comparison changes the emitted line.** That is deliberate: `hp > 0` instead of
  `not (hp <= 0)`. If you are diffing generated files after upgrading, that pair is the change.
- **A region cannot hold a local variable or a runtime switch.** If *Turn Into Region* is greyed,
  the item text says which of the three reasons it is.
- **Variables never fold as a block.** If you want a fold, make one: an Inspector group over
  variables, a group or a region over events.
- **The echo is the file, not a preview.** If a row's echo says something you did not expect, the
  file says it too - open the code panel on that row and read it there.
