# Updating and Refactoring Without Breaking Your Game

Every tool that generates code eventually asks you to trust it with the code it already generated. A
vocabulary moves on, a pack ships a new version, somebody renames a function, two branches merge -
and the question underneath all of it is the same: *what is going to happen to the sheets I already
have?*

This page is the answer, and the answer is short enough to say before the details: **nothing happens
to them until you press something.**

## Table of Contents

1. [Three promises, and what they cost](#three-promises-and-what-they-cost)
2. [The quiet amber question](#the-quiet-amber-question)
3. [A verb that moved says where it went](#a-verb-that-moved-says-where-it-went)
4. [Migrate: the receipt, and the two gates every rewrite passes](#migrate-the-receipt-and-the-two-gates-every-rewrite-passes)
5. [A worked migration, before and after](#a-worked-migration-before-and-after)
6. [The whole project at once](#the-whole-project-at-once)
7. [Renaming, in both directions](#renaming-in-both-directions)
8. [Taking a pack's new version](#taking-a-packs-new-version)
9. [The honest exit: keep it as code](#the-honest-exit-keep-it-as-code)
10. [What a merge leaves behind](#what-a-merge-leaves-behind)
11. [The contracts, as one command](#the-contracts-as-one-command)
12. [Working on this as a team](#working-on-this-as-a-team)
13. [Tips and common mistakes](#tips-and-common-mistakes)

## Three promises, and what they cost

Everything on this page is built on three sentences. They are not aspirations; each one is a gate in
the test suite and a check you can run yourself.

**1. A shipped game cannot break.** A sheet compiles to plain typed GDScript with no reference to this
plugin. Once that `.gd` is in your export it is yours, and nothing here can reach it. Updating the
plugin, updating a pack, or uninstalling the whole thing does not change a line of a game that is
already out.

**2. Old rows compile forever.** A verb's `ace_id`, its generated line and its place in the picker are
a compatibility promise from the day it ships. A verb that has been superseded keeps all three: it is
still in the picker, a row written on it still emits exactly the byte it always emitted, and the pack
that "retired" it retired nothing - it added a forwarding address beside it. There is no deletion in
this design, so there is no version of your project that stops compiling because time passed.

**3. Opening a sheet never rewrites it.** Open a `.gd` as a sheet, save it untouched, and you get the
same bytes back - and that stays true for a file full of spellings nobody uses any more, names nothing
answers to, and verbs the vocabulary has forgotten. Every migration, rename, re-mint and keep-as-code
on this page is an **edit a person approved in a dialog**, applied through the sheet's own undo funnel,
shown as a before-and-after receipt first. There is no code path anywhere in this plugin that rewrites
a sheet on open or on save. If there were, it would be the one bug that makes none of the rest worth
having.

The cost of those three is the thing worth naming, because it explains every design decision below:
**this plugin refuses far more than it accepts.** A rewrite it cannot prove is a rewrite it will not
make. A rename it cannot evidence is a rename it will not guess. That is why so much of what follows
is a list of the things a dialog *declined* to do, with a reason beside each one.

## The quiet amber question

Sheets get a lot of questions asked of them - a verb that moved, a name that went away, a pack that
changed under you. None of that is allowed to shout.

**A finding never renders in the sheet.** No block, no icon, no badge, no inline sentence, no hover
card. A row with something to answer wears the **quiet amber row state** and nothing else, and the
sheet's head grows at most **one counting line**. That is the whole of what a sheet says about itself.

![An event sheet whose head band reads migration, 1 row asks you, with a Migrate link beside it; the first event's row wears the quiet amber state and carries no icon or inline text, and the help strip at the foot reads LightFlicker no longer has this verb, the row still reads Flicker $Lamp by 0.4 and still compiles, with See what replaced it and Keep as code beside it](images/migration-amber-row.png)

The words live in two places, and only two:

- **The help strip under the selected row.** Click the amber row and the strip says what happened, what
  the row still reads as, what it still compiles to, and what you can do about it. Nothing is said
  until you ask by selecting.
- **The Doctor's triage inbox** (**Tools > Project Doctor**), which is where you go when you want the
  whole list rather than one row.

There is exactly one exception, and it is a state rather than a finding: a file holding **merge
markers** is not GDScript at all, so it banners at the head and opens read-only. That case is
[further down](#what-a-merge-leaves-behind).

The reason for the rule is not tidiness. A sheet is read by somebody trying to remember how their game
works, and a sheet covered in advisory chrome is a sheet that reads as broken. A row written five
versions ago against a verb that has since moved **is not wrong** - it compiles to the same line it
always did - so it gets the same visual weight as a row typed this morning, plus a colour you can
ignore until you have time.

## A verb that moved says where it went

When a verb is superseded, the old one stays exactly where it is and gains the **address** of the
newer spelling. On a built-in that is one call at the point the descriptor is built:

<!-- no-figure -->
```gdscript
.succeeded_by("Core::GoToState", {"next": "state"})
```

On a pack it is one annotation line, read off the file the way every other `@ace_*` line is:

<!-- no-figure -->
```gdscript
## @ace_succeeded_by(Core::GoToState, renames: next=state, defaults: seconds=1.0)
```

**The map says three things and no more:** the successor's id, what this row's parameters are called
over there, and a value for each parameter the old row never had. That is exactly enough for a
rewritten row to land complete, and it stops well short of anything that would turn a map into a
program. There is no expression to evaluate, no callback, no "conversion script".

Some properties of that worth knowing before you write one:

| Rule | What it means for you |
| --- | --- |
| The address is set where the descriptor is **built** | Definitions are immutable and shared for the whole session once generated, so nothing writes a successor into a cached one afterwards. A pack's address is read off its own file, like its name and its description |
| Chains resolve to the end | A verb superseded twice offers the verb you would write today, with the renames composed through the middle and the values re-keyed at each hop |
| A cycle is a build error | An address nobody is at, a chain that comes back on itself, a rename naming a parameter neither side has, or a successor parameter nothing answers fails `tools/audit_addons.gd` - which prints `successors=N problems=N` - rather than surprising somebody with a sheet open |
| Every address is auto-tested | One harness walks every map the installed vocabulary carries, builds a row on the old spelling, rewrites it, and puts the result through the real emitter and the real compiler: no unfilled slot, every renamed value arriving, the same byte twice |
| Superseded is not deprecated | The two are separate fields and separate ideas. A superseded verb can be a perfectly ordinary thing to have written; a deprecated one may have nowhere at all to go |

**In the sheet, this shows as nothing.** A row in the older spelling grows no amber, no icon and no
badge, because it is not wrong. Select it and one muted line appears on the help strip - *newer
spelling: Go To State* - with no door beside it.

![An event sheet whose head band reads migration, 1 row has a newer spelling, with a Migrate link; the selected action row Go to state "chasing" looks exactly like the ordinary row under it, and the help strip at the foot carries one muted line reading newer spelling: Go To State](images/successor-row-strip.png)

The head band is the other half, and it is derived from the rows rather than stored anywhere:

![A sheet head whose bands read class_name Sentry, extends CharacterBody2D, and one counting line - migration, 3 rows have a newer spelling, since 0.14.0 - with Migrate beside it; the four events underneath carry no mark of any kind](images/migration-head-band.png)

The *since* half comes from one project-level line, `eventsheets/project/vocabulary_version` in
Project Settings, remembering which vocabulary this project's sheets were last edited under. It is
written when a sheet is saved from the editor and only when it would change; a project that has never
carried it gets the same band without the version. **Nothing about the plugin is written into a
sheet's own file** - a `.gd` stays a `.gd` a hand author could have typed, with no version header and
no tool marker.

## Migrate: the receipt, and the two gates every rewrite passes

The counting line is a door. Press **Migrate…** and you get a receipt - and that dialog is the *only*
place a migration happens. Not on open, not on save, not automatically, and not from a report.

![The Migrate dialog: a lead line reading 2 row(s) would be rewritten in one step you can undo, and 1 are left exactly as they are; a What will be rewritten card showing each row's sentence today beside the sentence it would read and, indented under it, the line it writes today beside the line it would write; a Left exactly as they are card giving one row its reason; and Migrate These Rows beside Cancel](images/migration-migrate-dialog.png)

**The receipt is drawn in both languages a row has.** Every row that would be rewritten is shown
twice: the sentence it reads today beside the sentence it would read, and the line it writes today
beside the line it would write. That is deliberate. A receipt showing only the sentence hides the half
a reviewer will read in the diff; one showing only the line hides the half a beginner reads in the
sheet.

**Rows with nowhere to go are listed, not touched**, each with its own reason:

| The reason | What it means |
| --- | --- |
| the vocabulary has no newer spelling for this one | Nothing was ever forwarded. The row stays exactly as written, forever, and that is fine |
| the newer verb keeps state of its own | It has a member, a prelude, a hoisted term or a per-row token, so it has to be **picked** rather than rewritten - the dock bakes those when a row is applied and the compiler never does |
| the rewritten row could not be read back as the same row | The round-trip gate below said no |
| the rewritten line is not something this file would compile | The file gate below said no |

"12 rows migrated" printed over a list that quietly held 13 is how trust goes. So the count in the
lead line is over the rows in the card above it, and the ones it will not touch have their own card.

**Every rewrite proves itself twice before anything commits.**

1. **The row gate.** The rewritten row is emitted through the compiler's own emitter, the line it
   wrote is read back through the importer's own reverse grammar, and the row that comes back has to
   be the same verb writing the same byte. That is the lossless round-trip law asked one row at a
   time: a migrated line has to be a line this editor reads back as the row it just wrote, or the next
   person to open the file gets a different sheet.
2. **The file gate.** Reading a line back is not the same as the line being GDScript. A value that was
   a piece of text under the old verb can land in a slot the new one spells as a name, and emit and
   lift would agree with each other all the way to a file that will not parse. So the candidate is
   compiled into a **copy** of the sheet and the GDScript that comes out is put through Godot's own
   parser.

A row that fails either gate stays on the spelling it has, and the dialog says which gate and why.

**A migrated line reads as one somebody typed.** Values arrive under the names the successor calls
them, with a value for each parameter the old row never had - and nothing else. An argument that would
only restate what the callee already declares as its own default is not written, because it is not an
argument anybody typing the line would write. The row's reading is carried over too, so a migrated row
goes on saying something in the sheet if the pack it now names ever moves in its turn.

**Apply is one undo step.** Every proved row moves inside a single sheet edit, so one Ctrl+Z puts all
of them back with their ids, templates, values and readings unharmed.

## A worked migration, before and after

Here is what one looks like. A pack publishes *Say it*, taking a `message`; a later version publishes
*Announce*, which takes the same value under the name `text` and adds a `seconds` it declares a
default for. The old verb keeps its id, its template and its place in the picker forever, and gains
one line:

<!-- no-figure -->
```gdscript
## @ace_succeeded_by(SpeechPack::method:announce, renames: message=text)
func say_it(message: String) -> void:
```

This is the sheet before, written on the older verb:

<!-- caption: A sheet written on the older spelling -->
```gdscript
extends Node

func _ready() -> void:
	$SpeechPack.say_it("the gate is open")
```

Press **Migrate…** and the receipt shows that row twice over - the sentence it reads today beside the
sentence it would read, and the line it writes beside the line it would write:

| The sentence | Today | Rewritten |
| --- | --- | --- |
| the action | `Say it "the gate is open"` | `Announce "the gate is open"` |

| The line | Today | Rewritten |
| --- | --- | --- |
| the action | `$SpeechPack.say_it("the gate is open")` | `$SpeechPack.announce("the gate is open")` |

Note what is *not* in the rewritten line: `seconds`. The successor declares its own default for it,
and an argument that only restates what the callee already declares is not an argument anybody typing
the line would write. Read the file afterwards as a reviewer would - it is ordinary GDScript, typed
the way a person types it, with no marker saying a machine wrote it and no comment recording that a
migration happened. **That is the standard a rewritten row is held to**: if a row cannot land looking
like that, it does not land at all.

And the last thing a migration does not do: it does not delete the pack, it does not touch the child
node, and it does not go looking for other sheets to fix. It rewrites the rows in the receipt and
stops.

### The shipped vocabulary carries no forwarding address yet, and why that is the honest state

Nothing this plugin publishes today points anywhere. The pair that came closest was the **State
Machine** pack's *Go to state* and *Current state is* pointing at the built-in object-state *Go To
State* and *Is In State* - the same questions, one renamed parameter each - and it was withdrawn,
for two reasons worth knowing if you are about to write an address of your own.

**The value has to fit the slot as it stands.** The pack's parameter is a state NAME, so a row holds
the quoted literal a text field writes (`"chasing"`). The object-state parameter is a member of the
object's own `State` enum, so a row holds a bare name. A map may say three things - where, what the
parameters are called over there, and a value for what is new - and none of them turns one of those
into the other. The rewrite emitted `state = State."chasing"`, the file gate refused it correctly,
and every real row landed under *Left exactly as they are*. **A map is not a program**, deliberately,
so an address whose two ends store values differently is not an address.

**A coupled family moves together or not at all.** Those four verbs are one machine: *Time in state*
reads the clock *Go to state* stamps, and *On any state change* rides the signal it emits. Neither
has an honest address of its own. Forwarding the other two would have left the two that stayed
reading a member nothing writes any more - a machine that still compiles and no longer works. When a
successor moves a row to different storage than its unmigrated siblings read, the answer is to leave
all of them where they are.

## The whole project at once

One sheet at a time is the safe shape, but "how much of this is there?" is a project question. It has
two doors.

**The Doctor's Migration section** carries one line per sheet - *torch_room.gd - 11 row(s) migrate
cleanly, 1 ask you* - which double-clicks through to the sheet, plus one line per row whose verb the
vocabulary no longer has at all.

![The Doctor's triage inbox showing a Migration verb gone warning naming options_screen.tres, three notes under it - two per-sheet lines reading options_screen.tres, 3 rows migrate cleanly, 1 ask you and title_screen.tres, 2 rows migrate cleanly, 0 ask you - and a summary line, with a Fix chip reading Apply per sheet at the foot](images/migration-doctor-inbox.png)

The one chip on a per-sheet line is **Apply per sheet…**, and it opens that sheet's own receipt.
**Nothing applies from the report.** A report that rewrote files from a list nobody was looking at
would be the fatal version of this feature, so the report's only power is to open a door.

**`EventSheets.migration_report()`** is the same answer as data, for a build script or a branch gate:

<!-- no-figure -->
```gdscript
for row: Dictionary in EventSheets.migration_report():
	if row["asks"]:
		print("%s event %d still asks: %s" % [row["sheet"], row["row"], row["before"]])
```

One entry per row migration has something to say about, sorted and deterministic:

| Key | What it holds |
| --- | --- |
| `sheet` | The file the row lives in |
| `row` | Its 1-based place among that sheet's verb-carrying rows in reading order (conditions before actions, sub-events after their parent, functions last) - an address a person can count to, not a handle |
| `from_id` | `"<provider>::<ace_id>"`, the spelling it is written in |
| `to_id` | The same shape for the spelling it would be written in, empty when the vocabulary has no newer one |
| `before` | The line the row writes today |
| `after` | The line it would write once rewritten - non-empty **exactly** when `asks` is false |
| `asks` | True when a person has to decide |

A row written in the spelling the vocabulary uses today is not in the report at all, which is nearly
every row of nearly every sheet. Nothing is written, nothing is cached, and no entry carries a
timestamp or a machine path, so two machines given the same tree produce the same report. **The shape
is frozen like an `ace_id`** - a reader of it may be your own build script, and it will still be that
shape in five versions.

## Renaming, in both directions

A rename is the other half of refactoring, and it happens in two directions: you rename something, or
somebody else does.

### You rename it

A function's own head row offers **Rename…**, and the first thing the dialog draws is not a text field
with an OK button. It is the list.

![The Rename dialog: a New name field holding ring_alarm, a line reading Called by enemy.gd and traps.gd - 6 rows in 2 other files, this rewrites the 2 rows in this sheet and leaves those exactly as they are; a What will be rewritten card listing sound_alarm to ring_alarm twice; and a second card headed Named and left exactly as they are, listing enemy.gd - 4 rows and traps.gd - 2 rows](images/rename-receipt.png)

Two cards, and the second one is the interesting half. **Every other file that calls the name is
named, counted, and left exactly as it is**, under a heading that says why: the callers index answers
**by name**, so a file listed there may be calling a different function that happens to share the
spelling, and the index cannot tell. Being plainly approximate about who calls something costs a
reader one glance. Being quietly wrong about it costs them a broken game. A rename claiming "6 rows in
3 sheets" and touching four would be worse than saying nothing at all.

The button under the list is the only place a rename happens, it goes through the sheet's own undo
funnel, and one Ctrl+Z takes all of it back.

### Somebody else renamed it

The other direction is the one that used to be silent: somebody renames a function in the script
editor, or a node in the Scene dock, and the rows that pointed at it are suddenly holding a name
nothing answers to. Those rows wear the quiet amber, and the help strip says what happened.

![A sheet whose first event calls Sound Alarm and whose second calls Open Gate; the first row wears the quiet amber and carries no icon or inline text, and the help strip at the foot reads sound_alarm is no longer declared in guard.gd - it went out of the file in the same save that wrote it, that same save added, with a door reading Point the rows at ring_alarm](images/rename-outside-row.png)

**The "did you mean" beside it is evidence, never a guess.** It is offered only when the file's own
last save shows the old name vanishing and one name arriving - one save, one file, one swap:

- A near name that was **already in the file** before the save did not arrive, and is never offered.
- A save that brought several new names is answered only when **exactly one** of them is a near
  spelling of the old one. Two near spellings are two answers, which is none.
- A name that vanished with nothing arriving beside it has no candidate.

Anything weaker is a plainly amber row with the sentence, no door, and a cell you type into - which is
one double-click away and was never the hard part.

**The same rule reads a scene.** A row reaching `$Torch` after the node became `WallTorch` says so the
same way - *$Torch is gone from crypt.tscn. That same save gained $WallTorch* - and the door points
every row of the sheet at the new reference in one undoable step, through the token-safe replace that
knows `$Torch` is not `$TorchHolder`.

**It only ever knows what it watched.** The witness starts empty each session and files nothing on
first sight of a file, so a rename made while the editor was closed - a branch checkout, a pull - is
always the plain-amber case with no offer. That is the honest answer rather than a gap: the evidence
for a rename is a file's identity moving once with a name going out of it, and you have to have been
there to see it. It also means a headless run has watched nothing, so the Doctor's Renames section
reports its summary line and no findings on the command line, and says so.

**A `%name` stops the node half of this happening at all.** Godot's *Access as Unique Name* mark
survives every reparent, so a row written on `%HealthBar` only breaks if somebody renames the node
itself - and `$UI/Bars/HealthBar` breaks the moment anybody moves it. The parameter's help strip
offers **Make %HealthBar unique** where you are standing.

## Taking a pack's new version

A pack is **copied into your project** on purpose: once it is in `eventsheet_addons/` it is your code,
to read, edit and ship like anything else. That is the good half. The other half is that a year later
nobody can tell which of its files they changed - and an update that cannot tell either is an update
that either overwrites somebody's work or refuses to move at all.

So attaching a pack **writes down what arrived**: one small `pack_manifest.json` inside the pack's own
folder, holding the content hash of every file the attach landed. No mtimes - a checkout, a copy or a
sync moves those without touching a byte. The moment a file arrives is the only moment its arrival
state is knowable, so that is when it is recorded.

**Update…** then shows the whole proposal before a byte moves:

![The pack update dialog: a lead line reading 4 file(s) are exactly as they arrived and take the new version, 2 you changed, each with its own answer below; an Untouched card listing four files with what the new version does to each; a Yours card listing two files each with a Keep mine dropdown and a See the diff button; a What this version retires and adds card naming one verb that now points elsewhere and one that is new; and Take This Update beside Cancel](images/pack-update-dialog.png)

| The card | What it holds |
| --- | --- |
| **Untouched** | Files that still hash to what arrived. They take the new version - and they are **listed**, never swept: "we replaced eleven files you never opened" is something you get to read beforehand rather than discover afterwards |
| **Yours** | Every file that differs. One answer each: *Keep mine* (always the default), *Take new*, or *See the diff* |
| **What this version retires and adds** | The vocabulary difference, derived by diffing the two versions' **registry dumps** rather than by reading a release note or a version number |

Four details are worth knowing before you press anything:

- **A line-ending difference is a difference.** A file re-saved with the other platform's line endings
  does not hash to what arrived, so it is Yours - the honest answer to "did this change?" is the one
  the bytes give. The row says *only the line endings differ* beside it, so taking the new version is
  one click and not a mystery.
- **A pack with no record is not a pack with no changes.** The packs that ship inside the plugin were
  never attached, and neither was a folder somebody assembled by hand. Those put every file under
  Yours and default every one of them to *Keep mine*. "We do not know" and "you changed nothing" are
  different sentences, and only one of them is true.
- **Retiring a verb is still a forwarding address, never a deleted template.** A verb the new version
  retires keeps its id, its template and its place in the picker, and every row written on it compiles
  to exactly the line it always did. The row that mentions it opens the migrate dry run one click
  away, rather than asking for anything.
- **The old version goes to the backup ring first.** Every file the update is about to overwrite or
  remove is copied into the same per-file ring a sheet save uses, before the first new byte lands,
  and the line printed afterwards says how many went and names the folder they are in. That ring is
  a folder of files rather than a button: the editor's Restore menu restores **the sheet in front of
  you**, so a pack guide or icon the update took over is recovered by copying it back out of the
  ring. Knowing which is the point - a promise about a door that does not exist is worse than no
  promise.
- **The dry run answers the vocabulary the update would leave**, not the one you have. The
  forwarding addresses it is about are the incoming version's, and those do not exist in the packs
  installed today.

**Asking writes nothing under `res://`, and it runs the incoming code.** Reading a new version,
classifying every file and diffing both vocabularies leaves the pack byte for byte as it was. But
reading a version's verbs means REFLECTING it - the copy is written under `user://`, loaded and
instantiated, so its `_init` and any static initialiser execute, and then it is removed again. That
is what the live registry does for every pack you have installed; the difference here is that this
one is a version you have not accepted yet. An archive whose code you would not run is an archive
not to open.

### The registry dump

The vocabulary diff above is not prose, and it is available to you directly:

```
godot --headless --path . --script tools/dump_registry.gd
```

It prints every verb the project publishes as one sorted, stable text - key, type, category, params,
successor, template, tab separated, one verb per line, no timestamps and no machine paths. Two
questions in this plugin are the same question underneath: *what does this pack's new version retire
and add?* and *did this refactor change any verb's identity?* Both are answered by diffing two of
these texts with any tool you already have.

The six fields are the identity a sheet actually depends on. A descriptor's wording, its icon and its
examples may all change without a single emitted byte changing, so they are deliberately not in the
line.

## The honest exit: keep it as code

Sometimes there is no newer spelling, because the verb is simply gone: a pack was uninstalled, or a
studio's own vocabulary dropped it.

**Such a row is not broken.** Its generated template was baked onto it when it was applied, so it
compiles to exactly the line it always compiled to - and its **reading** was baked beside the template,
so it still says exactly what it said. What it has lost is the ability to be edited, re-picked or
explained. That is the whole of what is wrong, and the help strip says exactly that, naming what the
row still reads as and what it still compiles to.

Two doors, because there are two honest answers:

- **See what replaced it** opens the ordinary picker over the row - at the forwarding address when the
  vocabulary carries one, on the words of the old verb when it does not - and you choose.
- **Keep as code** turns the row into the same verbatim block every lift already falls back to.

![The Keep as code dialog: a paragraph saying this row keeps the line it already compiles to written out as code, an As it reads now card holding Flicker $Lamp by 0.4, an As it will be written card holding a comment line and flicker($Lamp, 0.4), a ticked Leave a comment above it checkbox, and Keep as code beside Cancel](images/migration-keep-as-code.png)

Keep as code shows the receipt first and proves itself before it commits. The sheet is compiled with
the block in place before the edit lands - the code without the comment, because the comment is a line
you asked for - and if a single byte of the rest of the file would move, the row is left exactly as it
is and the status line says so.

Two properties make this an exit rather than a trap:

- **The line comes from the compiler, not from a second emitter.** It is produced by the very call the
  compiler makes for that row, with the compiler's own arguments - the enclosing *With node X:* scope
  and the behaviour host accessor carried down the walk - so a row inside a scope keeps
  `$Enemy.flicker(0.4)` rather than a call on the wrong node.
- **The block re-lifts by itself.** What is written is exactly the shape the lift tables read, so a
  line kept as code today reads back as a picked row the day the vocabulary has the verb again.

The head band counts both halves when a sheet has both: *migration: 2 rows ask you - 12 migrate
cleanly*. The question leads and the reassurance follows, and the two counts are over different rows.

## What a merge leaves behind

Two failure modes are specific to working on sheets with other people, and both used to be silent.

### The doubled local

A verb whose generated line declares a local of its own bakes an eight-digit token into the name -
`__peer_a3f81c02`, `__spawn_1b0c77de` - so two copies of the same row cannot declare the same variable
twice in one function body.

A fresh token is now drawn against **every token the project's own scripts already hold**, not only
the ones this editor minted since it started, so two rows applied a year apart in two files can never
land on the same name. The point is not the collision that avoids, which was already vanishingly
unlikely. It is that a duplicate which *does* turn up cannot have come from ordinary work: it came
from two branches minting in parallel and a merge bringing both in.

So the Doctor reads it off the text and says it plainly - *Two rows both declare `__peer_a3f81c02` in
`_ready` (lines 7, 10)* - and offers one chip: **Re-mint one of them**. The row that was already in
the file keeps the name it had, the row the merge brought in gets a name of its own across all of its
baked fields at once, both rows go on reading exactly as they did, and Ctrl+Z puts it back. It is an
ordinary undoable sheet edit in the sheet's own history, and nothing is ever rewritten from the report.

### The file the merge did not finish with

![A sheet head banner naming the merge marker lines in the open file, with the file shown read-only underneath and nothing lifted into rows](images/merge-guards.png)

A file holding merge markers **opens read-only, and totally**: nothing is lifted into rows, Save is
refused, the unlock is gone, and the head banner names the marker lines. This is the one banner this
editor puts at the head of a sheet, and it is there because this is a **state** rather than a finding -
the file is not GDScript, so there is nothing to be quiet about.

The guard is textual and total, and both words are load-bearing:

- **Textual**, because a merge in trouble does not always leave a tidy region. Half of one gets resolved
  by hand and the closing `>>>>>>>` is left behind; an interrupted rebase leaves `|||||||`. Reading
  only well-formed regions answers "no conflicts" for every one of those files, and the sheet then
  lifts marker lines as code and offers to save over somebody's merge. Any marker line anywhere is
  enough. (A marker must **start** the line: an indented `=======` is a row of equals signs inside a
  comment, and blocking a file over one would be a guard nobody could get past.)
- **Total**, because a partial guard is not a guard. Finishing the merge belongs in the tool you
  started it in, and the banner says so; the side-by-side reading of the two versions is still one
  button away.

### The line endings that make every merge worse

Sheets are written with Unix endings on every platform. That is Godot's own convention, it is what the
compiler emits, and it is what the byte-exact round-trip assumes. A checkout with `core.autocrlf=true`
and no `.gitattributes` line quietly undoes it: every save becomes a whole-file diff, and two people
whose git is configured differently produce different bytes from the same edit, so conflicts become
routine instead of rare.

The Doctor notes which of the two it is looking at and shows the one line to commit:

```
*.gd text eol=lf
```

**This plugin never writes git configuration** - not `.git/config`, not `.gitattributes`, not a global
setting. A tool that reconfigures somebody's version control because it preferred a different answer
is a tool nobody can trust with a repository, so the fix is a line you put in your own diff. The note
is advisory and never a warning: a project that has lived happily with CRLF working copies is not
broken.

## The contracts, as one command

The three promises at the top are properties of the files sitting in your repository, and every one of
them can be checked without opening Godot:

```
godot --headless --path . --script tools/verify_sheets.gd
```

It reads your project without writing a byte of it, and it exits 0 or 1. Four checks, each one
sentence of the contract spelled out rather than described:

| Check id | The sentence it is | What a failure means |
| --- | --- | --- |
| `parses` | Every file is valid GDScript | A file nothing loads. Merge markers are named as themselves, with their line numbers |
| `round-trip` | Opening a file as a sheet and saving it untouched reproduces it byte for byte | Saving that file from the editor would change a byte nobody asked to change |
| `duplicate-local-token` | No scope declares one baked local twice | Two branches minted the same token and a merge brought both in. Godot refuses the file |
| `migration-asks` | The migration report holds no row waiting on a human | A row whose verb has moved and whose rewrite nothing can make for you |

A failure prints one line in the shape every compiler prints one, so a terminal that turns those into
links does:

```
res://player.gd:41 [duplicate-local-token] Two rows both declare __peer_a3f81c02 in _ready (lines 38, 41). Godot refuses a file that declares one name twice, so this will not run - it is two branches that minted the same token and a merge that brought both in. Re-mint one of them and both rows go on working. Project Doctor lists this line with one chip on it, Re-mint one of them, and the re-mint is an ordinary undoable sheet edit.
verify: 214 file(s) read, 1 failure(s).
```

**Every failure ends by naming the door in the editor that fixes it**, because this gate deliberately
fixes nothing. It reads; you decide.

Two things about it are easy to get wrong, so they are worth stating:

- **The check order looks wrong and is load-bearing.** Merge markers and doubled locals are asked
  *before* the engine's parse, because both of those **are** why the engine refuses the file, and both
  are readable off text the engine rejects. Asking the parser first would report a syntax error nobody
  can act on instead of the sentence that names the token and the chip that re-mints it.
- **Hand it paths and it reads exactly those.** Written the way git prints them or the way Godot writes
  them, both being the same file - which is what makes a pre-commit hook two lines long, at about a
  third of a second per file on top of the engine's start. Hand it nothing and it reads the whole
  project, which is what a branch gate wants. `--skip <prefix>` leaves out a folder of deliberately
  broken fixtures, which is the one thing this gate cannot tell from a real file.

The hook and CI recipes - the exact `pre-commit`, `pre-push` and workflow files, which are yours to
read before you install them - are in the version-control guide, along with the merge driver and the
readable-diff setup.

## Working on this as a team

### Everybody is on the same version, because the version is a commit

The plugin lives in `addons/` **inside your repository**. There is no per-machine install to keep in
step, so "which version of the editor are you on" is answered by `git log` like everything else. An
update is a commit, it is reviewed in a pull request, and checking out last month's commit gives you
last month's editor along with last month's sheets. A pack you attach is copied into the project the
same way, and is your project's code from that moment.

The one thing the plugin remembers about your project across sessions is a single line in
`project.godot`:

```
eventsheets/project/vocabulary_version="0.17.0"
```

Two branches that disagree about it resolve by taking either side: the value only moves forward, and
the next edit rewrites it. There is no sidecar file, nothing machine-local, and nothing anybody has to
remember to commit.

### A branch that has been open for three weeks

Nothing goes stale and nothing breaks. A superseded verb keeps its id, its template and its place in
the picker permanently, so a sheet written in an older spelling compiles to exactly the line it always
did - and no sheet is ever rewritten when it is opened or when it is saved, whatever spellings it
holds.

So a long-lived branch merges as ordinary code. Afterwards the sheet's head shows its counting line
again, **Migrate…** opens the receipt, and you take the rewrite when you want it rather than when a
merge decided for you. If you never take it, nothing is wrong: it compiles, it runs, and the Doctor
says so in one line.

### The branch gate is two questions

**Does it hold the contracts?** The verify command above, in CI, so a branch cannot merge a file that
does not parse, will not come back byte for byte, or declares one local twice.

**Is it leaving a decision for somebody else?** That is the fourth check, and the report behind it is
`EventSheets.migration_report()`. A row that does not `ask` can be rewritten on one click with a
receipt in front of you. A row that asks cannot be rewritten by anything, so landing a branch full of
them moves the decision onto whoever opens the file next month. That is what the gate is for - not
because those rows are broken, but because the person who should decide is the one looking at the
sheet.

### Reviewing the migration commit itself

A migration is an ordinary edit in the sheet's own undo history, so it arrives in review as an
ordinary diff: the rows that were rewritten, and nothing else. **That diff is the receipt**, and it
reads as code somebody typed rather than as machine output. Reviewing it is reviewing GDScript, which
is the only review anybody on the team has to know how to do.

## Tips and common mistakes

- **"Superseded" does not mean "hurry".** A sheet full of older spellings is a working sheet. The
  counting line is information, not a chore list, and a project that never migrates anything is a
  project this design is built to support.
- **Migrating rows does not add the declarations the newer rows need.** As in the worked example above,
  the file gate catches that and refuses - but the fix is yours: declare what the new spelling reads
  from, then migrate.
- **A row that asks is not a broken row.** It compiles and it runs. It is a decision, and decisions
  belong to people.
- **The callers list in a rename is by name, and says so.** Do not read "enemy.gd - 4 row(s)" as
  "four rows that will change". Nothing outside the sheet you are in is touched.
- **A rename made while the editor was closed has no evidence behind it**, so it gets no "did you
  mean". Type the name into the cell; that path is always open.
- **`%name` prevents the node half of this entirely.** It is worth the one click at the moment you drag
  a node into a field, not later.
- **Uninstalling a pack does not break the sheets that used it.** The rows keep their line and their
  reading. They go quiet-amber and lose the ability to be edited, which is a different and much
  smaller problem than the one people expect.
- **A file with no newline at its end fails the round-trip check.** Saving it from the editor adds one,
  which is a byte, which is the law. Adding the newline yourself is the whole fix.
- **Hooks are per-clone.** `.git/hooks` is not committed, so a teammate who has not set them up is
  stopped by nothing. Put the same command in CI, where it runs for everybody.
