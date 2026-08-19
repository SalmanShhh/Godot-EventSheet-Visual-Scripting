# Working with Text (and Reading Data Out of It)

Text is where a game meets the outside world. A player types a name into a box, a designer edits a
spreadsheet, a server sends back a reply, a dialogue writer marks a mood in square brackets, someone
pastes a level code into a field. All of it arrives as text, and all of it has to be made to fit a
label, read for the piece you actually want, or turned into rows you can loop over.

This guide covers the whole text surface as ordinary picker rows: fitting text into a fixed width,
formatting numbers a player can take in at a glance, lining columns up, turning an id into a readable
name, pulling one piece out of a line, splitting a console command without breaking a quoted phrase,
reading a `.csv` as records, and - the half everyone forgets - saying out loud what went wrong when
the file was malformed.

Everything here compiles to plain GDScript with no plugin dependency at runtime: **As Title Text**
on `item_id` emits `item_id.capitalize()`, and that line is the whole of it. Some rows carry more
than one branch - **Shorten To Fit** has to leave text that already fits alone and cope with a width
too narrow to hold its own ending - so what ships is a conditional expression rather than a single
call, but it is still plain GDScript you could have typed, with nothing of this plugin in it.

## Table of Contents

1. [The map: which folder holds what](#1-the-map-which-folder-holds-what)
2. [Making text fit a label](#2-making-text-fit-a-label)
3. [Numbers a player can read](#3-numbers-a-player-can-read)
4. [Columns that line up](#4-columns-that-line-up)
5. [Ids that read as names](#5-ids-that-read-as-names)
6. [Reading one piece out of a line](#6-reading-one-piece-out-of-a-line)
7. [Splitting a command without breaking a quoted phrase](#7-splitting-a-command-without-breaking-a-quoted-phrase)
8. [Asking questions about text](#8-asking-questions-about-text)
9. [A spreadsheet becomes rows: the CSV pipeline end to end](#9-a-spreadsheet-becomes-rows-the-csv-pipeline-end-to-end)
10. [Looping straight over text and folders](#10-looping-straight-over-text-and-folders)
11. [When the data is wrong, say so](#11-when-the-data-is-wrong-say-so)
12. [Sentences with slots, in every language](#12-sentences-with-slots-in-every-language)
13. [Full reference](#13-full-reference)
14. [Use cases](#14-use-cases)
15. [Tips and common mistakes](#15-tips-and-common-mistakes)

---

## 1. The map: which folder holds what

Every verb below is in the picker today. The categories are real folder names, so you can go straight
there instead of searching:

| Folder | What lives there |
| --- | --- |
| **Text** | Fitting, formatting, alignment, casing, and the extraction verbs (Text Before / Between / After, Number In Text, Split Keeping Quotes). |
| **Compare: Text** | The questions: Text Is A Number, Text Is A Whole Number, Contains Any Of / All Of / None Of, alongside the shipped Text Contains and Text Is One Of. |
| **Variables: String** | Number From Text and Whole Number From Text - the conversions that take a fallback. |
| **Files: Tables** | Table From File, Table From Text, Column Of Table, Row Where. |
| **Loops** | For Each Line In Text, For Each Part In Text, For Each Resource In Folder. |
| **JSON** | Explain JSON Problem, beside the shipped JSON Is Valid and the parse verbs. |
| **Variables: Dictionary** | Missing Fields - the "what is this record still lacking" report. |
| **Translation** | Translated Text From Pattern and Set Text (translated pattern). |

Expressions are reached from any value field with the **ƒx** button; conditions from **Add Condition**;
actions from **Add Action**.

---

## 2. Making text fit a label

A player name is 24 characters and the plate is 14. Left alone, the Label either overflows its panel or
silently clips, and a clipped name reads like a whole name - "Ancient Sword of Th" looks like an item
you do not own.

Two expressions fix it, and the difference between them is where the cut lands:

- **Shorten To Fit** trims by characters and marks the cut with an ending you choose.
- **Shorten To Whole Words** backs up to the last complete word first, so the result never ends
  mid-word.

```
On Ready
  -> Set Text of "PlayerName"   Shorten To Fit(profile_name, 14, "...")

Has Changed  current_objective
  -> Set Text                   Shorten To Whole Words(current_objective, 40, "...")
```

**In the editor**: Add Action › General Actions › **Set Text**, then press **ƒx** on the Text field ›
**Text** › **Shorten To Fit**. That is the same folder holding the shipped Left, Mid and Text Length.

Three promises both verbs keep, so you never have to reason about the edges:

- Text that already fits comes back untouched, character for character.
- The result never runs past the width you gave. A width too narrow to hold the ending cuts without
  one, so a 2-character budget can never return a 3-character `"..."`.
- Shorten To Whole Words falls back to cutting by characters when the budget holds no whole word (one
  very long word, or a window whose only space is its first character), so the result is never just
  the ending.

A common pairing is to keep the full text somewhere reachable:

```
Compare Values   Text Length(profile_name) > 14
  -> Set Text of "NameTooltip"   profile_name
```

---

## 3. Numbers a player can read

A score of `1234567` is unreadable at a glance, `0.73` is not a percentage, and a run timer written as
`mm:ss` says `"61:00"` an hour in.

| Verb | Reads | Good for |
| --- | --- | --- |
| **With Thousands Separators** | `1234567` becomes `"1,234,567"` | scores, currency, damage totals |
| **As Percent Text** | `0.73` becomes `"73%"` | health, completion, load progress |
| **As Duration** | `3725` becomes `"1h 02m"`, `90` becomes `"1m 30s"` | run timers, playtime, long cooldowns |

```
Timer "HudRefresh"  On Timeout
  -> Set Text of "Score"    With Thousands Separators(score)
  -> Set Text of "Health"   As Percent Text(Progress Of(health, 0, max_health), 0)
  -> Set Text of "Clock"    As Duration(seconds_left)
```

Three details worth knowing before you reach for one:

- **With Thousands Separators is whole numbers only** - anything after the decimal point is dropped,
  and a negative keeps its minus sign.
- **As Percent Text wants a 0-to-1 fraction.** The shipped **Percent Of** already returns 0 to 100, so
  feed this one the raw fraction (or divide Percent Of by 100). The shipped **Progress Of** returns
  0 to 1 and drops straight in, which is why the example above uses it.
- **As Duration survives passing an hour.** The shipped **As Clock Time** is strict `mm:ss` and rolls
  an hour into `"60:00"`, which is right for a lap timer and wrong for a playtime readout.

For idle-game scale (`1.23e15` shown as `"1.23 Qa"`), the Big Numbers pack ships formatters over its
own Decimal type. These three are the plain-float versions, so a comma in a score label does not
require registering an autoload first.

---

## 4. Columns that line up

Three expressions pad text to a fixed width so rows read as a table instead of drifting:

| Verb | Pads on | Result |
| --- | --- | --- |
| **Align Left** | the right | every row starts on the same edge |
| **Align Right** | the left | numbers END on the same edge |
| **Center In Width** | both sides | a heading sits in the middle of the column |

```
For each   entry   in   high_scores
  -> Add   Align Left(entry.name, 16, " ")             to board
  -> Add   Align Right(str(entry.score), 8, " ") + "\n" to board

Has Changed  board
  -> Set Text of "ScoreBoard"   board
```

Two rules that decide whether this actually works:

- **Give the Label a MONOSPACE theme font.** Padding counts characters, not pixels. In a proportional
  font `"iiii"` and `"WWWW"` are both four characters and visibly different widths, and the column
  drifts no matter what these verbs do. Every one of their descriptions says so for the same reason.
- **Text longer than the width is left alone.** These verbs never cut. Shorten it first (section 2),
  then align it - `Align Left(Shorten To Fit(name, 16, "…"), 16, " ")` is the full recipe for a
  leaderboard cell.

The **Fill with** parameter takes one character. A space is the usual choice; `"."` gives you the
dotted leader of a receipt or a contents page.

---

## 5. Ids that read as names

A data-driven game is full of machine ids: `fire_sword`, `maxHealth`, `quest_rescue_cat`. Showing one
to a player means either a second table mapping ids to labels (which drifts the first time somebody
adds a row) or a verb.

- **As Title Text** turns `"fire_sword"` into `"Fire Sword"` and `"maxHealth"` into `"Max Health"`.
- **As Sentence Text** raises the FIRST letter only and leaves everything else exactly as it is, so
  `"NPC"` and `"HP"` keep their capitals.

```
For each   key   in   stat_keys
  -> Set Text of ("Row_" + key)   As Title Text(key)
  -> Set Text of ("Val_" + key)   Align Right(str(Stat Total(key)), 6, " ")

On Item Picked Up
  -> Show toast   As Sentence Text("picked up " + As Title Text(item_id))
```

The shipped Uppercase and Lowercase destroy word shape and cannot produce a label - these two are the
missing half of that family.

---

## 6. Reading one piece out of a line

A dialogue line reads `Ada [angry]: hi`. You want the speaker, the mood and the words, and you do not
want to write index arithmetic or a regular expression to get them.

| Verb | Gives you | On the example line |
| --- | --- | --- |
| **Text Before** | the part before the first marker | `Text Before(line, " [")` is `"Ada"` |
| **Text Between** | the part between two markers | `Text Between(line, "[", "]")` is `"angry"` |
| **Text After** | everything after the first marker | `Text After(line, "]: ")` is `"hi"` |
| **Number In Text** | the first number anywhere in it | `Number In Text("Chapter 3")` is `3` |

```
On Line Started
  -> Set Variable   speaker = Text Before(line, " [")
  -> Set Variable   mood    = Text Between(line, "[", "]")
  -> Set Variable   says    = Text After(line, "]: ")

  Text Is One Of   mood, ["angry", "shouting"]
    -> Shake at   0.5
  -> Queue Line   speaker, says
```

**In the editor**: Add Action › Variables › **Set Variable**, then **ƒx** on the Value field › **Text**
› **Text Between**. The siblings sit in the same folder, next to the shipped Token At and Mid.

What each one does when the marker is not there is deliberate, and it is the difference between a
silent bug and an obvious one:

- **Text Before** gives you the WHOLE text back. With no marker to stop at, the part before the marker
  is the whole line, and nothing is silently lost.
- **Text After** gives you empty text, because with no marker there is no "after".
- **Text Between** gives you empty text when the OPENING marker is missing, and the rest of the text
  when the closing one is.
- **Number In Text** gives you `0` when there is no number at all. It reads whole and decimal numbers
  and keeps a leading minus, so `"v1.25-beta"` gives `1.25`.

---

## 7. Splitting a command without breaking a quoted phrase

The shipped **Split Text** is a bare split: `give "iron sword" 2` comes back as four pieces
(`give`, `"iron`, `sword"`, `2`), which is wrong for every console, chat command, cheat code and
search box ever built.

**Split Keeping Quotes** keeps anything inside `"double quotes"` together as one piece and drops the
quotes:

```
LineEdit "Console"   On Text Submitted
  -> Set Variable   words = Split Keeping Quotes(entry, " ")

  Array Is Empty   words
    -> Log   "type help for commands"

  Text Equals (ignore case)   words[0], "give"
    -> Add Entry   words[1], words[1], Number From Text(words[2], 1)

  Text Equals (ignore case)   words[0], "goto"
    -> Go To Scene   words[1]
```

Empty pieces are skipped, so a run of separators (a double space between words) never produces blanks
you then have to filter out.

---

## 8. Asking questions about text

### Would this convert to a number?

`Text To Int` and `To Integer` answer `0` for `"abc"`, for `""` and for `"0"` alike, so a typo in an
amount box arrives as a real-looking bet of nothing. Ask first:

- **Text Is A Number** - true when the text would convert cleanly. Spaces around the number are
  ignored; empty text is not a number.
- **Text Is A Whole Number** - the same question for a count, a level or a slot index. `"12"` passes
  and `"12.5"` does not.

And convert with a fallback YOU chose, instead of a surprise zero:

- **Number From Text**(text, or) and **Whole Number From Text**(text, or), both in **Variables: String**.

```
LineEdit "Amount"   On Text Submitted

  Text Is A Number   $Amount.text
    -> Set Variable   bet = Number From Text($Amount.text, 0)
    -> Set Property   "disabled" of Button "Bet" to false

  Else
    -> Set Text of "Hint"   "Numbers only, please"
    -> Set Property   "disabled" of Button "Bet" to true
```

**In the editor**: Add Condition › **Compare: Text** › **Text Is A Number** (the folder where Text Is
Blank lives), then **ƒx** on the value field › **Variables: String** › **Number From Text**. The
failure branch is the shipped **Add 'Else'** on the row menu.

`"12.5"` is not a whole number, so Whole Number From Text lands on the fallback rather than quietly
becoming `12`. When you want that rounding, use Number From Text and round the result yourself.

### Does it contain any of these?

Three conditions test one piece of text against a whole LIST, instead of an Or block with five Text
Contains rows in it:

```
Contains Any Of   chat_line, banned_words
  -> Set Variable   chat_line = "***"
  -> Show toast     "Message blocked"

Contains All Of   card_text, ["Burn", "Chain"]
  -> Add   1   to combo_bonus

Contains None Of   player_name, banned_words
  -> Call Function   accept_name(player_name)
```

The list is an ordinary expression, so it can be a sheet variable somebody edits without ever touching
the row. Three things to know:

- Matching is **case-sensitive**, and it looks INSIDE the text. The shipped **Text Is One Of** is a
  different question: it needs the WHOLE text to equal an entry.
- An **empty list is never a match** for Contains Any Of.
- An **empty list counts as true** for Contains All Of (nothing is missing) and passes Contains None
  Of (nothing forbidden appeared).

---

## 9. A spreadsheet becomes rows: the CSV pipeline end to end

This is the pipeline every data-driven game reaches eventually: a designer edits a spreadsheet, the
game reads it, and adding content is adding a row rather than adding events.

### The file

`res://data/items.csv`, with the column names on the FIRST line:

```csv
id,label,price,rarity,stock
rusty_sword,Rusty Sword,10,common,5
iron_sword,"Iron Sword, forged",45,rare,2
health_potion,Health Potion,8,common,20
```

Note the second row: a quoted cell may contain the separator, and the parse keeps it as one field.

### Reading it

**Table From File** turns that into one record per row, each field reachable by column name:

```
On Ready
  -> Set Variable   items = Table From File("res://data/items.csv", ",")
```

**In the editor**: Add Action › Variables › **Set Variable**, then **ƒx** on the Value field ›
**Files: Tables** › **Table From File**. The **Separator** field is a dropdown - Comma, Semicolon,
Tab - because those are what a spreadsheet export actually writes.

What the parse promises, so you are never guessing:

- The first line is the column names. A **blank** column name is skipped (no row could address it),
  and a **repeated** column name keeps the first column's value, so `row["price"]` and
  **Column Of Table** can never disagree about which column they meant.
- **Quoted cells** may contain the separator, and a doubled `""` inside such a cell is one literal
  quote character.
- **Windows (CRLF) and old-Mac (CR) line endings** are normalised, blank lines are dropped, and a
  missing trailing newline is a non-event.
- A **short row** fills its missing columns with empty text instead of being dropped; cells past the
  last column name are ignored.
- A **missing or unreadable file** simply gives no rows - no red error.

**Table From Text** is the same parse over a blob you already hold: a paste, a downloaded body, a file
you read earlier.

### Checking it before you trust it

A spreadsheet edited by a person will eventually contain `abc` in a price column. Say so:

```
  Array Is Empty   items
    -> Log   "items.csv had no rows"   as Error

  Text Is Blank   Explain Table Problem(items, ["price", "stock"])   (inverted)
    -> Log   Explain Table Problem(items, ["price", "stock"])   as Warning
```

**Explain Table Problem** returns the first offending cell as a sentence -
`row 12, column "price": "abc" is not a number` - and empty text when every listed column checks out.
Empty IS the all-clear, which is why the branch above inverts a **Text Is Blank**.

Rows are counted from 1 over the rows you HOLD. Table From File has already used up the header line,
so row 12 in the report is line 13 of the file.

### Using it

Loop the records and hand each one to a pack, converting the text columns as you go:

```
  For each   row   in   items
    -> Add Entry   row["id"], row["label"], Number From Text(row["price"], 0)

    Text Equals (ignore case)   row["rarity"], "rare"
      -> Add Entry   "rare_pool", row["id"], 1
```

Two reading verbs save you a loop when you only want one slice:

- **Column Of Table**(items, "label") gives one whole column as a list, in row order - a dropdown's
  items, a weights list, a quick sum.
- **Row Where**(items, "id", "iron_sword") finds the FIRST record whose column holds that value. It
  compares as text, so `25` and `"25"` both match a cell reading `25`, and it gives an EMPTY record
  when nothing matches - check it with **Dictionary Is Empty** before reading fields.

```
  -> Set Variable   chosen = Row Where(items, "id", picked_id)

  Dictionary Is Empty   chosen
    -> Log   "no such item: " + picked_id   as Error
  Else
    -> Set Text of "Price"   With Thousands Separators(Number From Text(chosen["price"], 0))
```

Every cell arrives as TEXT, always. That is the one thing to remember about a CSV: numbers in a
spreadsheet are still characters in a file, so a price column goes through Number From Text and a
count goes through Whole Number From Text before it does any arithmetic.

---

## 10. Looping straight over text and folders

Three CONDITIONS land in the event's loop lane, so the event's actions run once per item without a
separate split-then-pick-filter step:

| Condition | Runs once per | Read the current one as |
| --- | --- | --- |
| **For Each Line In Text** | line of the text, blank lines skipped | `line` |
| **For Each Part In Text** | piece between separators, trimmed, blanks skipped | `part` |
| **For Each Resource In Folder** | `.tres` / `.res` in a folder, already loaded | `entry` |

```
On Ready
  -> Set Variable   blob = Read Text File("user://scores.csv")

  For Each Line In Text   blob
    -> Set Local Variable   who = Token At(line, ",", 0)
    -> Add   Align Left(who, 16, " ") + "\n"   to board

    For Each Part In Text   Text After(line, ","), ";"
      -> Push Back   part   to all_tags

  For Each Resource In Folder   "res://data/items"
    -> Load From Resource   entry
```

**In the editor**: Add Condition › **Loops** › **For Each Line In Text**. It lands in the loop lane
automatically, the way a looping condition does.

Because these apply as pick filters, the loop index, frame-spreading and byte-exact round-trip all
come from machinery that already ships. Three edges worth knowing:

- Line endings are normalised first, so no line arrives with a stray carriage return.
- For Each Part In Text trims each piece and skips empty ones, so `"sword; shield;; bow"` is three
  parts.
- A folder that is not there walks nothing, quietly - it is checked first, so a loop that runs every
  frame cannot spam errors. Anything that fails to load is skipped rather than arriving as nothing.

---

## 11. When the data is wrong, say so

A malformed file produces nothing, and the crash happens three rows later in a row that looks
innocent. Three expressions name the failure where it happened, and they share one convention that
makes them safe to branch on: **an EMPTY result means nothing is wrong.**

| Verb | Answers | Example result |
| --- | --- | --- |
| **Explain JSON Problem** | why this JSON would not parse | `line 4: Expected ':'` |
| **Explain Table Problem** | the first cell that should be a number and is not | `row 12, column "price": "abc" is not a number` |
| **Missing Fields** | which listed fields a record or resource left blank | `tiles, spawn_point` |

```
On Ready
  -> Set Variable   raw = Read Text File("user://config.json")

  Text Is Blank   Explain JSON Problem(raw)   (inverted)
    -> Log        "config.json: " + Explain JSON Problem(raw)   as Error
    -> Go To Scene   "res://ui/data_error.tscn"

  Text Is Blank   Missing Fields(level_data, "name, tiles, spawn_point")
    -> Build from   level_data
  Else
    -> Log   "Level unusable, missing: " + Missing Fields(level_data, "name, tiles, spawn_point")   as Error
```

**In the editor**: Add Action › Debug › **Log**, then **ƒx** on the Message field › **JSON** ›
**Explain JSON Problem**. The invert is the shipped **Invert Condition** on the condition's row menu.

Three things these promise:

- **Branch on the report's own emptiness**, not on JSON Is Valid. That shipped condition reads a file
  holding just the word `null` as invalid, while Explain JSON Problem correctly has nothing to say
  about it - pairing the two logs an error with a blank reason.
- **Missing Fields reads a record OR a resource**, and blank means nothing there: no value at all,
  empty text, an empty list or an empty record. A `0` is a real value and is never reported.
- **Explain Table Problem reports a row that is not a record at all**, which is what a table read by
  some other route looks like. That matters because empty is this family's all-clear: a diagnostic
  that could not read its input and said nothing would wave the malformed file straight through the
  branch that exists to stop it.

---

## 12. Sentences with slots, in every language

Composing the shipped **Text From Pattern** with the shipped **Translate** the natural way looks up a
string that has ALREADY had its slots filled - `"You have 7 coins"` - and no catalog can contain that,
so the label silently stays in the source language forever.

**Translated Text From Pattern** does it in the order that works: look the whole sentence up FIRST,
fill the slots second.

```
Function   On refresh_hud
  -> Set Text (translated pattern)   "You have {coins} coins"   with   {"coins": coins}
  -> Set Text of "Wallet"   Translated Text From Pattern("{name}: {amount}", {"name": wallet_name, "amount": amount})

On Language Changed
  -> Call Function   refresh_hud()
```

The pattern you type - slots and all - IS the translation key, so `You have {coins} coins` is the line
that goes in your catalog. Re-run the label under **On Language Changed** so it follows a live
language switch.

**In the editor**: Add Action › **Translation** › **Set Text (translated pattern)**, or any text
field's **ƒx** › **Translation** › **Translated Text From Pattern**.

---

## 13. Full reference

### Fitting and formatting (folder: Text)

| Verb | Kind | Emits |
| --- | --- | --- |
| Shorten To Fit | Expression | a length test, then `text.left(budget).strip_edges() + suffix` |
| Shorten To Whole Words | Expression | the same, backing up to the last space first |
| With Thousands Separators | Expression | a `RegEx` digit grouping over `str(absi(int(value)))` |
| As Percent Text | Expression | `String.num(value * 100.0, decimals) + "%"` |
| As Duration | Expression | `"%dh %02dm"` past an hour, `"%dm %02ds"` below it |
| Align Left | Expression | `text.rpad(int(width), fill)` |
| Align Right | Expression | `text.lpad(int(width), fill)` |
| Center In Width | Expression | an `lpad` to half the gap, then an `rpad` to the width |
| As Title Text | Expression | `text.capitalize()` |
| As Sentence Text | Expression | `text.substr(0, 1).to_upper() + text.substr(1)` |

### Extraction (folder: Text)

| Verb | Kind | Emits |
| --- | --- | --- |
| Text Before | Expression | `text.get_slice(marker, 0)` |
| Text After | Expression | the split-once form, empty when the marker is missing |
| Text Between | Expression | split once on the opener, then slice to the closer |
| Number In Text | Expression | a `RegEx` number search with a `"0"` tail |
| Split Keeping Quotes | Expression | a quote-aware fold over the pieces |

### Questions (folders: Compare: Text, Variables: String)

| Verb | Kind | Emits |
| --- | --- | --- |
| Text Is A Number | Condition | `str(text).strip_edges().is_valid_float()` |
| Text Is A Whole Number | Condition | `str(text).strip_edges().is_valid_int()` |
| Contains Any Of | Condition | `Array(options).any(func(n): return text.contains(n))` |
| Contains All Of | Condition | the same with `.all` |
| Contains None Of | Condition | the same with `.any`, negated |
| Number From Text | Expression | the checked `to_float()`, else your fallback |
| Whole Number From Text | Expression | the checked `to_int()`, else your fallback |

### Tables and loops (folders: Files: Tables, Loops)

| Verb | Kind | Emits |
| --- | --- | --- |
| Table From File | Expression | the header-row parse over `FileAccess.get_file_as_string(path)` |
| Table From Text | Expression | the same parse over text you hold |
| Column Of Table | Expression | `table.map(func(r): return r.get(column, ""))` |
| Row Where | Expression | a `reduce` that keeps the first match, `{}` otherwise |
| For Each Line In Text | Condition (loops) | the normalised `split("\n", false)` |
| For Each Part In Text | Condition (loops) | a split, trimmed, blanks dropped |
| For Each Resource In Folder | Condition (loops) | the guarded folder walk, loaded, nulls dropped |

### Reports (folders: JSON, Files: Tables, Variables: Dictionary)

| Verb | Kind | Emits |
| --- | --- | --- |
| Explain JSON Problem | Expression | a bound `JSON` instance, its error line and message |
| Explain Table Problem | Expression | the first bad cell as a sentence, `""` when clean |
| Missing Fields | Expression | the blank field names, comma-joined |

### Translation (folder: Translation)

| Verb | Kind | Emits |
| --- | --- | --- |
| Translated Text From Pattern | Expression | `tr(pattern).format(values)` |
| Set Text (translated pattern) | Action | `text = tr(pattern).format(values)` |

---

## 14. Use cases

### 1. A leaderboard that lines up

Align Left the names, Align Right the scores, Shorten To Fit anything over the column width, and give
the Label a monospace theme font. Fifteen rows read as a table instead of a ragged list.

### 2. An amount box that cannot bet nothing

Text Is A Number gates the Confirm button, Number From Text does the conversion with your own
fallback, and the Else branch says "Numbers only, please" instead of quietly staking zero.

### 3. A shop stocked from a spreadsheet

`items.csv` opens in any spreadsheet app, Table From File reads it on ready, a For Each adds one entry
per row, and the designer adds an item by adding a line.

### 4. An in-game console

Split Keeping Quotes turns `give "iron sword" 2` into three words, `words[0]` picks the command, and
each branch is one condition row.

### 5. A dialogue script with mood tags

Text Before, Text Between and Text After split `Ada [angry]: hi` into speaker, mood and line, and the
mood drives a screen shake.

### 6. A chat filter a moderator can edit

Contains Any Of tests the message against a `banned_words` sheet variable, so the list is data
somebody can edit without opening the row.

### 7. Item labels with no second table

As Title Text turns every `fire_sword` id straight into "Fire Sword", so ids and labels can never
drift apart in two places.

### 8. A run timer that survives the hour mark

As Duration reads `"1h 02m"` where a strict `mm:ss` clock would say `"62:00"`.

### 9. Telling a modder what they broke

Explain JSON Problem prints `line 4: Expected ':'` into the log and the game goes to a friendly error
scene instead of crashing three rows later.

### 10. A balance pass that fails loudly

Explain Table Problem over `["price", "stock"]` runs on ready in debug builds, so a typo in the
spreadsheet is a warning on the first run, not a crash on a customer's machine.

### 11. A folder of items IS the item list

For Each Resource In Folder walks `res://data/items`, already loaded, so adding an item is dropping a
`.tres` in a folder with no registry to maintain.

### 12. A half-authored level caught at the door

Missing Fields against `"name, tiles, spawn_point"` gates the build action, and the error names
exactly which fields are still blank.

### 13. A HUD that follows a live language switch

Set Text (translated pattern) keeps `"You have {coins} coins"` as the catalog key, and On Language
Changed re-runs the refresh function.

### 14. A leaderboard blob parsed in one event

For Each Line In Text walks a downloaded body directly, with no intermediate split-into-a-variable
step.

### 15. Version strings and chapter numbers

Number In Text pulls `3` out of `"Chapter 3"` and `1.25` out of `"v1.25-beta"` without anybody writing
a pattern.

**Other use cases**: **a search box respecting "exact phrase"** (Split Keeping Quotes on the query),
**a receipt-style summary** (Align Left with `"."` as the fill for a dotted leader), **a tag list in
one spreadsheet cell** (For Each Part In Text split by `";"`), **a save-slot title that fits its
tile** (Shorten To Whole Words at the tile width), and **a debug overlay of stat keys** (As Title Text
down the left column, Align Right down the right).

---

## 15. Tips and common mistakes

- **Every CSV cell is text.** A price column is characters until you convert it. Put Number From Text
  or Whole Number From Text between the cell and any arithmetic.
- **Alignment needs a monospace font.** Align Left / Right / Center In Width count characters. In a
  proportional font the column will drift however correct the padding is.
- **Alignment never cuts.** Shorten first, then align. Text longer than the width comes back untouched
  by design, because silently losing a name is worse than one ragged row.
- **An empty report is the all-clear.** Explain JSON Problem, Explain Table Problem and Missing Fields
  all return empty text when nothing is wrong, so the failure branch is a **Text Is Blank** with
  **Invert Condition** on it.
- **Do not pair Explain JSON Problem with JSON Is Valid.** That condition reads a document holding
  just the word `null` as invalid and this verb has nothing to say about it, so together they log an
  error with a blank reason. Branch on the report's own emptiness.
- **Translate first, fill second.** Wrapping Text From Pattern in Translate looks up a string that
  already has its values in it, which no catalog holds, so the text never translates. Use Translated
  Text From Pattern.
- **Row Where gives an empty record on a miss**, not nothing. Guard it with Dictionary Is Empty before
  reading a field, or the field read comes back as an empty string and travels quietly.
- **Text After is empty when the marker is missing; Text Before is the whole line.** That asymmetry is
  deliberate - "the part before" of a line with no marker really is the whole line, while there is no
  "after" at all.
- **Contains Any Of is case-sensitive and looks inside.** If you want whole-string equality against a
  list, that is the shipped **Text Is One Of**, which is a different question with a similar name.
- **Keep the value expression a plain read.** Number From Text and the fallback verbs read their input
  twice in the emitted line, so a method that consumes, deals or advances something would run twice.
