# Autocomplete, and typing a row as a sentence

The plugin already knows every name your sheet can say: it compiles them all. This is about the
editor giving them back to you as you type - in the dialogs, in the rows themselves, and in the Add
picker, with one list behind all of them and one set of keys to learn.

Two features, one seam:

- **Autocomplete** offers the names a field can hold, filtered as you type. It rides the value
  fields in dialogs, the value you double-click inside a row, the name fields, the type fields and
  the file fields.
- **Quick add** lets you type a whole row into the Add picker's search box - object, verb and value,
  in any order - and press Enter.

## Contents

- [The keys](#the-keys)
- [What completes where](#what-completes-where)
- [Typing inside a row](#typing-inside-a-row)
- [Quick add: type the sentence, get the row](#quick-add-type-the-sentence-get-the-row)
- [Code boxes keep Godot's own completion](#code-boxes-keep-godots-own-completion)
- [For pack authors: the completions seam](#for-pack-authors-the-completions-seam)
- [Why it stays fast on a big project](#why-it-stays-fast-on-a-big-project)

## The keys

The same four, everywhere a suggestion list appears:

| Key | What it does |
|---|---|
| **Tab** or **Enter** | accepts the highlighted suggestion |
| **Escape** | closes the list and keeps exactly what you typed |
| **Up** / **Down** | move the highlight (it wraps at both ends) |
| anything else | ordinary typing - the list narrows as you go |

They are Godot's own code-completion keys on purpose. If you already write GDScript in this editor
you knew them before you met this feature, and if you do not, you learn them once and they work in
the next field along.

The list ranks best-first: the whole name you typed, then a name starting with it, then a name whose
*word* starts with it (`shader` finds `set_shader_parameter`), then a name containing it, then a hit
in the explaining line beside it. Three letters or more also match letters-in-order, so `stt` finds
`Set Time Scale`. Under three letters that tier is off - `hp` is inside half the engine's method
names, and finding all of them would bury the variable you meant.

## What completes where

| Where | What it offers |
|---|---|
| A **value** field (the `ƒx` boxes, and the value you double-click in a row) | your sheet's variables with their scope and type, the members of the class it extends, `Autoload.member` globals, the parameters your own functions declare, and GDScript's own `max()`, `clamp()`, `randf()` and friends |
| After a **dot** | just that thing's members: `hp.` offers what an `int` can do, `$Sprite.` offers that node's, `State.` offers the enum's values |
| After **`$`** or **`%`** | the open scene's node paths, and its unique names |
| A **name** field | the sheet's functions (a Call row), its signals (an emit row), node groups with how many nodes are in each, an enum's values, and the project's Input Map actions with the keys bound to each |
| A **type** field (the Sheet type dialog's *Extends*, the variable dialog's `@onready` type) | the classes that make sense there - your project's own `class_name` scripts first, then the engine's - each with the editor's own icon beside it |
| A **file** field | `res://` paths, filtered to the resource type the field takes (a scene field offers scenes, a sound field offers sounds) |

A dial of a shader material completes by name in the field that asks for one. It does not complete
inside a value field, because `effect.dissolve` is a *reading* the row shows rather than something
you can write in GDScript - the code is `material.get_shader_parameter("dissolve")`, and the row is
what writes that for you.

## Typing inside a row

Double-click a highlighted value in a row and you get the same list, and the same keys, that the
dialog showing that parameter gives you. That is the whole point of there being one seam: the fast
gesture is not the blind one.

An important difference between the two kinds of field, which the popup handles for you:

- In a **value** field, accepting swaps only the word under the caret. `health + ma` **Tab** becomes
  `health + max()`, and everything you already wrote stays.
- In a **name**, **type** or **file** field, accepting replaces the field, because the field holds
  one value and you have just chosen which.

## Quick add: type the sentence, get the row

Open Add action and type what you want to happen:

```text
boss fla 0.4
```

The picker reads that as three things: `boss` and `fla` are words that FIND a row, and `0.4` is a
VALUE that FILLS one. **Boss ▸ Flash white for 0.4 s** comes first, with the 0.4 already in it -
press **Enter** and the parameters dialog opens on a filled field, or press **Tab** to step into the
parameters and change one.

The rules, so it never surprises you:

- Words match in **any order**, and against any part of the row: its name, the node it is aimed at
  (a picker shelf entry's `$Boss`), its category and its keywords. Every word has to hit something,
  so a word you did not mean narrows the list rather than widening it.
- A **value** is a number (`0.4`, `12`) or text in quotes (`"hello"`). Nothing else - a bare word is
  always a word, because typing `red` means you are looking for a row about red, not filling a field
  with it.
- A value lands in the **first parameter that can take it** and has not already been answered: a
  number in a number or expression field, quoted text in a text field. A dropdown, a colour swatch
  or a node reference takes none, so nothing lands somewhere it cannot be shown.
- Anything a shelf entry already chose for you - the node an effect row is aimed at, the function a
  Call row calls - is never overwritten by a value from the query.

Nothing about this is a second Add flow. It is the same picker, the same Enter, the same parameters
dialog. It is only faster than the mouse.

## Code boxes keep Godot's own completion

A **Script block** is a GDScript editor, and it stays one: it keeps the engine's completion popup,
its icons and its keys. So does the `ƒx` value box in a dialog, which is a code editor too, and so
do the pick-filter fields. What the plugin adds to all three is the *vocabulary* - your sheet's
variables, functions, enums, parameters and host members, from the same seam every other field asks
- so a name completes the same way whichever box you are typing in.

That is also why the keys can be the same everywhere: the plugin's own popup copies the engine's
model rather than inventing a second one, and there is no second completion engine anywhere in this
plugin to disagree with the first.

## For pack authors: the completions seam

One public call answers every field:

```gdscript
EventSheets.completions_for(sheet, field_kind, prefix) -> Array[Dictionary]
# -> [{"text": "hp", "detail": "Player · Instance whole number hp = 100", "kind": "variable"}, ...]
```

`text` is what accepting inserts, `detail` is the line shown beside it, and `kind` is a stable id
naming what sort of thing it is (`variable`, `member`, `function`, `signal`, `group`, `action`,
`node`, `class`, `file`, `dial`, `enum`, `builtin`).

**`field_kind` is your parameter's own `hint`.** A parameter you ship with
`"hint": "input_action"` completes against the project's Input Map without you writing a line, and
one with a hint nobody has heard of completes with nothing, which leaves it an ordinary typed field
rather than one offering somebody else's list. Three kinds have no hint behind them and are named
directly - `"function_name"`, `"class_name"` and `"file"` - and a kind may carry an argument after a
colon, exactly as the hints already do: `"file:PackedScene"`, `"enum_value:State"`.

To answer a kind of your own (or to sharpen one the plugin already answers):

```gdscript
EventSheets.register_completion_source("my_pack.quest_id", func(sheet, _kind) -> Array:
	# Return entries, or plain Strings for the simplest case.
	return [{"text": "quest_intro", "detail": "the tutorial one", "kind": "variable"}])
```

And to put the popup on a field in a dialog of your own, with the same keys as everywhere else:

```gdscript
EventSheets.attach_completions(my_line_edit, "my_pack.quest_id")
```

`prefix` is what has been typed. For `"expression"` pass the whole text **before the caret** (`hp.`
and `hp` want different answers, and only that can tell them apart); for every other kind pass the
word itself.

## Why it stays fast on a big project

Building a list is allowed to be slow. Typing is not. So each kind's list is built **once** - the
first time a field of that kind is completed - and every keystroke after that only filters what is
already in hand. A keystroke never scans your project, opens a scene or reads a file.

The lists are dropped again at exactly the two moments an answer can change: when you **edit the
sheet** (a variable added, a function renamed) only that sheet's lists go, and when the **filesystem
changes** (a scene saved, an action added in Project Settings, a shader edited) all of them do. The
answers about the project - the Input Map, the node groups, the class list, the file list - are held
once and shared by every open tab, so ten tabs asking for the Input Map is one Input Map.

## No walls: a greyed entry is a fix, and no result is ever empty

An entry the picker cannot honestly offer yet is never hidden. It stays listed, greyed, with the
one-line reason on it - and selecting it turns the Add button into the fix itself. A behavior-host
verb off a plain sheet offers to make the sheet a behavior; an Editor verb on a game sheet offers
to switch Tool on; a verb whose node the open scene lacks offers to add that node (through the
editor's own undo, so Ctrl+Z takes it back); a node trigger on a sheet no scene carries offers to
attach the sheet. Press the fix and the row's own dialog opens right after, as if nothing had ever
been in the way.

![The Add Event picker with a behavior-host condition selected: the description panel explains
Host Is Valid, and the dialog's confirm button reads "Make this a behavior sheet…" instead of
Add](images/picker-gate-fix.png)

A search that matches nothing is not a dead end either. The same ranker relaxes - a word that
found nothing no longer disqualifies an entry - and the nearest entries stand under a **Nearest
matches** section. Under them, **Recipes**: whole worked examples drawn from the guides' own
figures, inserted into the sheet as real rows in one undo step, ready to retune.

![The Add Event picker after a query with no exact match: a Nearest matches section listing wall
and jump entries, then a Recipes section offering a worked example from a guide](images/picker-recipes.png)
