# Working With Text

**Working With Text** is the builtin vocabulary for cutting a string apart, searching it, testing it
and turning it into (or out of) a number. It is four bodies of verbs that answer the same question at
four levels of effort: the plain **Text** verbs (Left, Mid, Trim, Replace In Text, Text From Pattern),
the **Variables: String** tests and conversions (Text Contains, Split Text, Text To Int, Pad Number),
the **Text: RegEx** pattern verbs for when a fixed marker is not enough, and the no-pattern
**extraction** set (Text Before / Text After / Text Between / Number In Text / Split Keeping Quotes)
that names the piece you want instead of the index arithmetic that computes it.

Every one of these compiles to a plain Godot String call. There is no runtime, no autoload and no
plugin reference in the emitted code - a row that reads "the part of line before ` [`" ships as
`line.get_slice(" [", 0)`.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Building a message** out of a pattern and some values, with no format codes to learn.
- **Reading a log or dialogue line** apart: the speaker, the mood tag, the line itself.
- **Parsing pasted or typed input** - a console command, a search box, a cheat code.
- **CSV-ish columns** where a comma or a pipe separates fields.
- **Validation** - is this text a number, does it look like an email, does it start with `res://`.
- **Score and timer readouts**: zero-padded numbers, `mm:ss` clocks, fixed decimal places.
- **Filenames and paths** - the part before the dot, the part after the last slash.
- **Version strings** where you want the first number and do not care about the rest.
- **Tag stripping and censoring** - swap every match of one substring, or every match of a pattern.
- **Counting** - how many commas, how many matches, how many tokens.

## Core concepts

- **Expressions go in cells, actions go in rows.** Almost everything here is an EXPRESSION: a value
  you drop into a parameter cell (a Label's text, another verb's argument, a comparison). Only a
  handful of text verbs anywhere in the vocabulary are actions.
- **Nothing here changes the text you gave it.** Godot strings are values, so Trim, Replace In Text
  and Uppercase all hand back a NEW string. Store the result somewhere or it is gone.
- **Index-free first.** Text Before / Text After / Text Between exist so you never have to write
  Find In Text and then Mid with an arithmetic offset. Reach for the index verbs only when the piece
  you want is genuinely positional (the first three characters, the last four).
- **A missing marker has a documented answer, not an error.** Text Before hands back the WHOLE text
  (with nothing to cut at, the part before the marker is everything). Text After hands back an EMPTY
  string (with no marker, there is no "after"). Find In Text answers -1. Number In Text answers 0.
  Every one of those is a value you can branch on.
- **Conversions never fail loudly.** `Text To Int` on `"abc"` is 0 and `Text To Float` on `""` is
  0.0. That silent zero is the single most common bug in this whole family, which is why **Value Is
  Text** and the tests below exist.
- **Patterns are a last resort, not a first one.** Text Between reads better than a regex and is
  faster to get right. Reach for **Text Matches Regex** and friends when the shape varies - digits
  anywhere, an optional sign, a repeated group.
- **Tokens are 0-based.** Token At with index 0 is the first column.

## Verb reference

On the canvas these read as sentences with the parameter values drawn in place, e.g.
*the part of `line` between `[` and `]`*, *pad `score` to `6` digits*, *`name` contains `sword`*.

### Text (the plain string toolkit)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Text From Pattern | Fills `{name}` slots in a pattern from a record of values - the friendly way to mix words and numbers, no format codes. | `{pattern}.format({values})` |
| Left | The first N characters. | `{text}.left({count})` |
| Right | The last N characters. | `{text}.right({count})` |
| Mid | A chunk starting at a position, for a length. | `{text}.substr({from}, {count})` |
| Text Length | How many characters the text holds. | `{text}.length()` |
| Trim | The text with leading and trailing whitespace removed. | `{text}.strip_edges()` |
| Uppercase | The text in all capitals. | `{text}.to_upper()` |
| Lowercase | The text in all lower case. | `{text}.to_lower()` |
| Find In Text | Where a substring first appears, or -1 when it is missing. | `{text}.find({needle})` |
| Replace In Text | Every match of one substring swapped for another. | `{text}.replace({what}, {with})` |
| Token At | The chosen piece after splitting on a separator, like a CSV column. | `{text}.get_slice({separator}, {index})` |
| Token Count | How many pieces the text breaks into. | `{text}.get_slice_count({separator})` |
| Zero Pad | A number padded with leading zeros to a fixed width (007). Digits first, then the value. | `("%0*d" % [{digits}, {value}])` |
| To Text | Any value as text, for joining into messages. | `str({value})` |
| Value Is Text | CONDITION: true when the value really holds text - the guard before any string work on a loaded value. | `typeof({value}) == TYPE_STRING` |

### Variables: String (tests, splits and conversions)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Text Contains | CONDITION: the substring appears somewhere inside. | `{text}.contains({needle})` |
| Text Begins With | CONDITION: the text starts with the prefix. | `{text}.begins_with({prefix})` |
| Text Ends With | CONDITION: the text ends with the suffix. | `{text}.ends_with({suffix})` |
| Split Text | The text chopped into a list wherever the separator appears. | `{text}.split({separator})` |
| Text To Int | The text parsed into a whole number. | `{text}.to_int()` |
| Text To Float | The text parsed into a decimal number. | `{text}.to_float()` |
| Pad Number | The number padded with leading zeros. Value first, then the digit count. | `str({number}).pad_zeros({digits})` |
| Repeat Text | The text repeated N times - bar charts, separators, indentation. | `{text}.repeat({count})` |

### Text (a duration as a clock)

| Verb | What it does | Ships as |
|------|--------------|----------|
| As Clock Time | Seconds as `mm:ss` - 90 reads `01:30`. A negative duration reads as zero. | `("%02d:%02d" % [int(maxf({seconds}, 0.0)) / 60, int(maxf({seconds}, 0.0)) % 60])` |

### Text: RegEx (when a fixed marker is not enough)

Every one of these compiles the pattern inline with `RegEx.create_from_string`, so there is no
pre-built RegEx object to declare and nothing to keep in a variable.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Text Matches Regex | CONDITION: the pattern matches anywhere in the text. | `RegEx.create_from_string({pattern}).search({text}) != null` |
| Regex Replace | The text with EVERY match replaced. `$1` / `$2` in the replacement reuse capture groups. | `RegEx.create_from_string({pattern}).sub({text}, {replacement}, true)` |
| Regex First Match | The first matching substring, or empty when nothing matches. | `(RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string()) + [""]).front()` |
| Regex Match Count | How many times the pattern matches (0 if none). | `RegEx.create_from_string({pattern}).search_all({text}).size()` |
| Regex All Matches | A list of every matching substring (empty list if none). | `RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string())` |
| Regex Capture Group | Capture group N from the first match - the text inside the Nth pair of parentheses. | `(RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string({group})) + [""]).front()` |
| Format Decimals | A number as text with a fixed number of decimal places: 3.14159 to 2 dp reads `3.14`. | `String.num({value}, {decimals})` |

### Text (extraction, in words)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Text Before | The part before the FIRST marker. Missing marker gives the whole text back, so nothing is silently lost. | `{text}.get_slice({marker}, 0)` |
| Text After | Everything after the FIRST marker. Empty when the marker is not there. | `str((Array({text}.split({marker}, true, 1)) + [""])[1])` |
| Text Between | The part between an opening and a closing marker. Empty when the opener is missing, the rest of the text when the closer is. | `str((Array({text}.split({open}, true, 1)) + [""])[1]).get_slice({close}, 0)` |
| Number In Text | The first number anywhere in the text, whole or decimal, signed or not. 0 when there is none, and you never write a pattern. | `(RegEx.create_from_string("-?[0-9]+(\\.[0-9]+)?").search_all({text}).map(func(__m): return __m.get_string()) + ["0"]).front().to_float()` |
| Split Keeping Quotes | Splits on a separator but keeps `"quoted phrases"` together as one piece and drops the quotes. Empty pieces are skipped. | `Array({text}.split("\"")).reduce(func(__acc, __part): return [not __acc[0], __acc[1] + ([__part] if __acc[0] and not __part.is_empty() else Array(__part.split({separator}, false)))], [false, []])[1]` |

## Use cases

**1. A score readout with no format codes.** Text From Pattern is the beginner's building block: the
pattern reads like the sentence it produces.

```
Every tick
  -> set ScoreLabel text = Text From Pattern("{player} scored {score}!", {"player": player_name, "score": score})
```

It emits exactly the call you would have written by hand:

```gdscript
text = "{player} scored {score}!".format({"player": player_name, "score": score})
```

**2. A leaderboard number that keeps its width.**

```
On score changed
  -> set ScoreLabel text = Pad Number(score, 6)
```

`Pad Number` takes the value first and the digit count second; `Zero Pad` takes the DIGITS first.
Both produce `000420` for 420, so pick one and stay with it.

**3. A countdown clock.**

```
Every tick
  -> set TimerLabel text = As Clock Time(time_left)
```

90 seconds reads `01:30`. It is strictly mm:ss, so an hour rolls into `60:00` rather than `1:00:00`.

**4. Clean up what the player typed before you store it.**

```
On name field submitted
  -> set player_name = Trim(NameField.text)
  Condition: Text Length(player_name) = 0
    -> set player_name = "Player"
```

**5. A case-blind command check.** Lowercase both sides and the comparison stops caring about the
shift key.

```
On console line entered
  Condition: Lowercase(Trim(line)) = "restart"
    -> restart the level
```

**6. Read a chat or log line apart without any index arithmetic.** For the line
`Ada [angry]: hi`:

```
On log line received
  -> set speaker = Text Before(line, " [")
  -> set mood    = Text Between(line, "[", "]")
  -> set said    = Text After(line, "]: ")
```

That is `Ada`, `angry` and `hi`. Written with Find In Text and Mid it is six rows and two off-by-one
bugs.

**7. Split a console command the way a console should.**

```
On console line entered
  -> set parts = Split Keeping Quotes(line, " ")
```

`give "iron sword" 2` is three pieces, not four, and the quotes are gone. Runs of spaces never
produce blank pieces.

**8. Pull the number out of a label you did not author.**

```
On chapter header read
  -> set chapter = Number In Text(header)
```

`Chapter 3` gives 3, `v1.25-beta` gives 1.25, and a header with no number at all gives 0 rather than
an error.

**9. A CSV row, one column at a time.**

```
On line read from file
  -> set item_id  = Token At(line, ",", 0)
  -> set price    = Text To Float(Token At(line, ",", 2))
```

Token indexes count from 0. Pair Token Count with a Repeat loop when the column count varies.

**10. Guard a conversion so a typo cannot read as zero.**

```
On field submitted
  Condition: Text Matches Regex("^-?[0-9]+$", entry)
    -> set amount = Text To Int(entry)
  Else
    -> show "Please type a whole number."
```

Without the guard, `Text To Int("abc")` is 0 and the player silently transfers nothing.

**11. A filename and its extension.**

```
On file dropped
  -> set base      = Text Before(file_name, ".")
  -> set extension = Lowercase(Text After(file_name, "."))
  Condition: Text Ends With(Lowercase(file_name), ".png")
    -> load it as an image
```

**12. Strip BBCode-style tags out of a line.**

```
On line shown
  -> set plain = Regex Replace("\\[[^\\]]*\\]", raw_line, "")
```

One pattern removes every `[tag]`, however many there are. Replace In Text cannot do this because it
needs a fixed substring.

**13. Censor a word list.** Replace In Text is the fixed-substring form and composes:

```
On message posted
  -> set clean = Replace In Text(Replace In Text(message, "damn", "****"), "hell", "****")
```

For more than a handful of words, one Regex Replace with alternation (`damn|hell|blast`) is one row
instead of ten.

**14. Count something in a line.**

```
On line parsed
  -> set field_count = Token Count(line, ",")
  -> set number_count = Regex Match Count("[0-9]+", line)
```

**15. Pull a named piece out of a structured string with a capture group.** For `hp:42/100`:

```
On stat line read
  -> set current = Text To Int(Regex Capture Group("hp:([0-9]+)/", stat_line, 1))
```

Group 1 is the text inside the first pair of parentheses. A miss gives an empty string, which
`Text To Int` reads as 0 - so guard it with Text Matches Regex first if 0 is a meaningful value.

**16. Every match, as a list.**

```
On dialogue loaded
  -> set every_tag = Regex All Matches("\\[[a-z]+\\]", script_text)
  For Each item in every_tag
    -> register the mood tag
```

The result is an ordinary list, so For Each takes it directly.

**17. Money with exactly two decimal places.**

```
Every tick
  -> set PriceLabel text = "$" + Format Decimals(price, 2)
```

`String.num` rounds rather than truncating, so 3.14159 at 2 dp is `3.14` and 2.999 at 2 dp is `3.00`.

**18. A text bar drawn out of characters.**

```
Every tick
  -> set BarLabel text = Repeat Text("#", int(health / 10)) + Repeat Text(".", int((max_health - health) / 10))
```

**19. Refuse to do string work on something that is not a string.**

```
On save loaded
  Condition: Value Is Text(loaded["name"])
    -> set player_name = Trim(loaded["name"])
  Else
    -> set player_name = "Player"
```

A number, a null or a missing key would all reach a `.strip_edges()` call and error; the condition
turns that into a branch.

### Other use cases

**Cheat-code entry.** Keep the last N key names in a string, and Text Ends With the code you are
listening for - one condition replaces a whole index-tracking state machine.

**Search-box filtering.** Lowercase both the query and each item name, then Text Contains to decide
which rows stay visible, so the filter is case-blind for free.

**Version gate on a save file.** Number In Text on the saved version string gives a number you can
compare, whatever decoration ("v1.4-beta") the string carries around it.

**Localised key hygiene.** Text Begins With `"UI_"` on every key your sheet feeds to a translation
verb, logged when it fails, catches a hand-typed sentence that was never meant to be a key.

**Import sanity check.** Regex Match Count of `"[0-9]+"` across a pasted block tells you at a glance
whether a spreadsheet column arrived as numbers or as words, before you convert any of it.

## Tips and common mistakes

- **A failed conversion is a silent zero.** `Text To Int` and `Text To Float` answer 0 for anything
  they cannot read, including an empty string. If 0 is a legal value in your game, guard the
  conversion (Text Matches Regex, Value Is Text) rather than trusting the result.
- **Number In Text answers 0 for "no number too".** Same trap, same fix: check the text first when a
  real 0 and a missing number must be told apart.
- **Text Before and Text After disagree about a missing marker on purpose.** Before gives you the
  whole text (nothing is lost); After gives you an empty string (there is no "after"). Neither is a
  bug and neither errors, but a row that assumed the other one will look broken.
- **Text Between with a missing CLOSING marker gives the rest of the text.** A missing OPENING marker
  gives empty. If both cases must be caught, test with Text Contains first.
- **Replace In Text is single-pass and literal.** It swaps a fixed substring, all occurrences, in one
  sweep - it does not re-scan its own output and it understands no pattern syntax. Nested or
  overlapping replacements need a Regex Replace or a second row.
- **Zero Pad and Pad Number take their arguments in opposite orders.** Zero Pad is
  `(digits, value)`, Pad Number is `(number, digits)`. Reading the row's sentence rather than the
  cell order is the reliable way to tell.
- **As Clock Time never grows an hours field.** It is mm:ss by design, so an hour reads `60:00`. When
  the duration can pass an hour, use As Duration from the Making Text Readable On Screen vocabulary.
- **Token indexes start at 0** and `Token At` past the end gives an empty string, not an error.
- **Split Text hands back a PackedStringArray, not a plain list.** Most things accept it happily; if
  a verb refuses it, the builtin List Or verb converts and defaults in one step.
- **A regex pattern lives in a string, so backslashes double.** `\d` is typed `"\\d"` in a cell. The
  RegEx verbs default to `"[0-9]+"` for exactly this reason - it needs no escaping at all.
- **The regex verbs compile their pattern every time they run.** That is what makes them one-liners
  with no setup, and it is fine in an event or a UI update. In a per-frame row over hundreds of
  items, do the match once and keep the answer in a variable.
- **Regex First Match and Regex Capture Group answer "" on a miss** rather than erroring, so a failed
  match silently becomes an empty string. Pair them with Text Matches Regex when the difference
  matters.
- **Nothing here edits in place.** `Trim(name)` does not change `name`; assign the result back.
