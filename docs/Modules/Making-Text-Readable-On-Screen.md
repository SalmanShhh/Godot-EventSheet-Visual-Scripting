# Making Text Readable On Screen

**Making Text Readable On Screen** is the builtin vocabulary for the last step before a value reaches
a Label: shortening it so it fits, grouping its digits so a player can take it in, lining it up into
a column, translating it in the right order, and then checking that it physically fits in the pixels
it was given.

It is two halves that answer the same question at two levels of precision. The **formatting** rows
work in CHARACTERS and words: Shorten To Fit, With Thousands Separators, As Percent Text, As
Duration, the three column expressions, As Title Text, As Sentence Text and the two
translated-pattern rows. The **drawn** rows work in PIXELS, through Godot's own
`Font.get_string_size`: Text Overflows, Fit Text To Label, Text Fits In Width and Wrapped Text
Height, plus the font and direction rows that decide whether the text can be drawn at all in someone
else's language.

Every template is plain GDScript over native calls. No runtime, no helper library, no autoload.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [How Fit Text To Label works](#how-fit-text-to-label-works)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Item names in a fixed slot** - clipped with a visible mark, never a half-word that reads whole.
- **Big scores** that need commas before anybody can read them.
- **Health, loading and completion percentages** as text beside the bar.
- **Run timers and cooldowns** that must survive passing an hour.
- **Text tables** - an inventory, a scoreboard, a debug overlay lined up in columns.
- **Machine ids shown to players** - `fire_sword` reading as `Fire Sword` with no second list.
- **Localised sentences with values in them**, looked up in the right order so they actually translate.
- **Buttons that a longer language overflows** and nobody notices until a store review.
- **Japanese, Russian and emoji builds** that would otherwise draw a wall of empty boxes.
- **Right-to-left languages** where the whole layout has to mirror, hand-placed offsets included.
- **Dialogue boxes** that need to know how tall the line becomes before it is shown.

## Core concepts

- **Characters are not pixels.** Shorten To Fit counts characters, which is exactly right for a
  monospace readout and increasingly wrong as the font gets more proportional. When the answer has to
  be true on screen, measure: Text Fits In Width and Text Overflows ask the font itself.
- **A control does not draw what `text` holds.** Godot auto-translates a Control's own text at
  display time, so a Label still holding `START GAME` draws its German translation. Every row here
  that measures a control's own text goes through the same lookup the engine does, which is why
  Text Overflows answers about the language on screen rather than about English.
- **Overflow only means something on a control that cannot grow.** A Label free to widen is grown by
  the engine to fit its text, and honestly answers "no overflow". Turn on Clip Text, set a Text
  Overrun Behavior, or put it in a fixed-size container - which is the control you were worried about
  anyway.
- **Translate first, fill second.** The whole sentence, `{slots}` and all, is the translation key.
  Filling the slots and THEN translating looks up a string no catalog can contain, so the label
  silently stays in the source language forever. Translated Text From Pattern and Set Text
  (translated pattern) make the correct order the easy one.
- **The fallback chain is what draws foreign glyphs.** A font that has no glyph for a character draws
  a box unless its `fallbacks` chain has one that does. Add Font Fallback appends to that chain and
  is idempotent, so it is safe on every load and every language change.
- **Direction is a setting, not a string operation.** One row on your UI root takes the layout
  direction from the game's language, and containers, anchors and margins mirror themselves.
- **Nothing here mutates a value in place** except the two ACTIONS: Set Text (translated pattern),
  Use Font, Mirror Layout For Language, Add Font Fallback and Fit Text To Label. Everything else is
  an expression you drop into a cell.

## Reference tables

Two shorthands appear in the Shorten templates below, written out here so the table stays readable.
They are literal text in the emitted code, not anything to look up:

- **B** (the budget) is `maxi(int({max_chars}) - {suffix}.length(), 0)` - the room left once the
  ending has been paid for, never below zero.
- **H** (the hard cut) is `{text}.left(maxi(int({max_chars}), 0))` - what happens when the width
  cannot hold the ending at all.

### Text (fitting by characters)

| Name | What it does | Ships as |
|------|--------------|----------|
| Shorten To Fit | Trims to a maximum character count and marks the cut, so a clipped name never reads as a whole name. Text that already fits is untouched, and the result never runs past the width you gave. Cuts mid-word. | `({text} if {text}.length() <= int({max_chars}) else ({text}.left(B).strip_edges() + {suffix} if B > 0 else H))` |
| Shorten To Whole Words | The same, but backs up to the last complete word first, so "Ancient Sword of Thorns" reads "Ancient Sword..." not "Ancient Sword of Th". Falls back to the character cut when the budget holds no whole word. | `({text} if {text}.length() <= int({max_chars}) else (({text}.left(B + 1).rsplit(" ", true, 1)[0].strip_edges() + {suffix}) if (B > 0 and {text}.left(B + 1).contains(" ") and not {text}.left(B + 1).rsplit(" ", true, 1)[0].strip_edges().is_empty()) else ({text}.left(B).strip_edges() + {suffix} if B > 0 else H)))` |

### Text (readable numbers)

| Name | What it does | Ships as |
|------|--------------|----------|
| With Thousands Separators | Grouped digits a player can read at a glance: 1234567 reads `1,234,567`. Whole numbers only, the fraction is dropped; a negative keeps its minus sign. | `(("-" if float({value}) < 0.0 else "") + RegEx.create_from_string("(\\d)(?=(\\d\\d\\d)+$)").sub(str(absi(int({value}))), "$1,", true))` |
| As Percent Text | A 0-to-1 fraction as percent TEXT with the sign on it: 0.73 reads `73%`. | `(String.num(float({value}) * 100.0, maxi(int({decimals}), 0)) + "%")` |
| As Duration | Seconds as a duration that survives passing an hour: 3725 reads `1h 02m`, 90 reads `1m 30s`. A negative duration reads as zero. | `(("%dh %02dm" % [int(maxf({seconds}, 0.0)) / 3600, (int(maxf({seconds}, 0.0)) % 3600) / 60]) if int(maxf({seconds}, 0.0)) >= 3600 else ("%dm %02ds" % [int(maxf({seconds}, 0.0)) / 60, int(maxf({seconds}, 0.0)) % 60]))` |

### Text (columns)

These pad; they never cut. They only truly line up in a MONOSPACE font.

| Name | What it does | Ships as |
|------|--------------|----------|
| Align Left | Pads on the RIGHT to a fixed width, so every row starts on the same edge. | `{text}.rpad(int({width}), {fill})` |
| Align Right | Pads on the LEFT to a fixed width, so numbers END on the same edge. | `{text}.lpad(int({width}), {fill})` |
| Center In Width | Pads on BOTH sides. An odd leftover space goes on the right. | `{text}.lpad({text}.length() + (int({width}) - {text}.length()) / 2, {fill}).rpad(int({width}), {fill})` |

### Text (case that keeps word shape)

| Name | What it does | Ships as |
|------|--------------|----------|
| As Title Text | A machine id as a readable name: `fire_sword` reads `Fire Sword`, `maxHealth` reads `Max Health`. | `{text}.capitalize()` |
| As Sentence Text | Raises the FIRST letter only and leaves the rest exactly as it is, so `NPC` and `HP` keep their capitals. Empty text stays empty. | `({text}.substr(0, 1).to_upper() + {text}.substr(1))` |

### Translation (the right order, and the right direction)

| Name | What it does | Ships as |
|------|--------------|----------|
| Translated Text From Pattern | Looks the whole sentence up in the current language FIRST, then fills its `{slots}`. The pattern, slots and all, is the translation key. | `tr({pattern}).format({values})` |
| Set Text (translated pattern) | ACTION on a Label: the same, written straight into its text. | `text = tr({pattern}).format({values})` |
| Language Reads Right To Left | CONDITION: true while the game runs in Arabic, Hebrew, Persian, Urdu. The engine answers, so a language added later is covered without editing a list of codes. | `TextServerManager.get_primary_interface().is_locale_right_to_left(TranslationServer.get_locale())` |
| Mirror Layout For Language | ACTION on a Control: this control and everything under it lays itself out from the game's language. One row on your UI root usually covers the whole game. | `layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE` |
| Layout Is Mirrored | CONDITION on a Control: true when it is currently laid out right to left. Ask it before a hand-placed offset or a slide-in tween. | `is_layout_rtl()` |

### UI (fonts and glyphs)

| Name | What it does | Ships as |
|------|--------------|----------|
| Add Font Fallback | ACTION: any character the main font cannot draw is drawn by the fallback instead. Adding the same fallback twice does nothing, so it is safe on every load and after every language change. | `if {fallback} != null and not {font}.fallbacks.has({fallback}):` then `{font}.fallbacks = {font}.fallbacks + [{fallback}]` |
| Use Font | ACTION on a Control: gives ONE control its own font with no theme resource. The Slot list covers RichTextLabel's four separate faces. | `add_theme_font_override({slot}, {font})` |
| Font Of This Control | The font this control is really drawing with right now, whether from a theme, a Use Font row or the engine default. | `get_theme_font(&"font")` |
| Font Can Show | CONDITION: true when the font has a glyph for every character in the text, empty text included. It follows the fallback chain. | `({text}.is_empty() or Array(range({text}.length())).all(func(__i): return {font}.has_char({text}.unicode_at(__i))))` |

### Text (fit, measured in pixels)

| Name | What it does | Ships as |
|------|--------------|----------|
| Text Overflows | CONDITION on a Control: true when the text is wider than the control showing it. Measures what the control DRAWS, in its real font. Takes an optional **On node** so one row can ask about another control. | `{target.}get_theme_font(&"font").get_string_size({target.}atr(str({target.}text)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, {target.}get_theme_font_size(&"font_size")).x > {target.}size.x` |
| Fit Text To Label | ACTION on a Control: backs the text up until it MEASURES inside the control and marks the cut. Also takes an **On node**. | a multi-line block, see [How Fit Text To Label works](#how-fit-text-to-label-works) |
| Text Fits In Width | CONDITION: true when the text would draw no wider than that many pixels - the check for a control you are about to fill or size, before it exists on screen. | `{font}.get_string_size({text}, HORIZONTAL_ALIGNMENT_LEFT, -1.0, {font_size}).x <= float({width})` |
| Wrapped Text Height | How TALL the text becomes once it wraps into a box that wide, in pixels. | `{font}.get_multiline_string_size({text}, HORIZONTAL_ALIGNMENT_LEFT, float({width}), {font_size}).y` |

## How Fit Text To Label works

Fit Text To Label is the only multi-line template in this vocabulary, and the shape is worth knowing
because it explains the one surprising thing it does: **the cut is not one-way**.

A Control re-translates the string its `text` still HOLDS. If the row wrote a cut German string
straight into `text`, switching back to English would leave the German cut on screen forever. So the
row parks the string it was handed in the node's `fit_source_text` meta the first time it runs, and
every later run starts from THERE. Re-run it under On Language Changed and the label re-fits the new
language; a line that now fits is written back in full and auto-translates itself again like an
untouched label.

The emitted block reads, with the `{uid}` the compiler bakes per applied row:

```gdscript
extends Label


if not has_meta(&"fit_source_text"):
	set_meta(&"fit_source_text", str(text))
text = str(get_meta(&"fit_source_text"))
var __fit_font_a1: Font = get_theme_font(&"font")
var __fit_px_a1: int = get_theme_font_size(&"font_size")
var __fit_room_a1: float = size.x
var __fit_cut_a1: String = atr(str(text))
```

followed by the trim loop: it measures, takes one character off at a time until the line fits the
budget, backs up to the last whole word unless that would leave nothing, and drops the ending marker
entirely when nothing survived - so the result is never just the ending and never wider than the
control.

That is the same set of edge rules the character-based Shorten expressions follow, deliberately: two
families that disagree about the same string would be worse than one that is only approximate.

## Use cases

**1. An item name in a fixed slot.**

```
On item selected
  -> set NameLabel text = Shorten To Whole Words(item_name, 20, "...")
```

`Ancient Sword of Thorns` reads `Ancient Sword...`. Shorten To Fit would give
`Ancient Sword of Th...`, which reads like a different item.

**2. A score nobody has to count digits in.**

```
Every tick
  -> set ScoreLabel text = With Thousands Separators(score)
```

**3. Health as a percentage beside the bar.**

```
Every tick
  -> set HealthPercentLabel text = As Percent Text(health / max_health, 0)
```

Feed it a 0-to-1 fraction. The builtin Percent Of expression already returns 0-to-100, so divide that by
100 rather than passing it straight in.

**4. A run timer that survives an hour.**

```
Every tick
  -> set RunTimerLabel text = As Duration(run_seconds)
```

`1h 02m` past the hour, `1m 30s` below it. Use As Clock Time from the Working With Text vocabulary
when you specifically want strict `mm:ss`.

**5. An inventory laid out as a table.**

```
For Each item in inventory
  -> add line = Align Left(item["name"], 18, ".") + Align Right(To Text(item["count"]), 4, " ")
```

Give the Label a monospace font with Use Font or the columns still drift:

```
On Ready
  -> InventoryLabel: Use Font  load("res://fonts/mono.ttf"), Main font
```

**6. A centered heading in the same table.**

```
On panel built
  -> set HeaderLabel text = Center In Width("INVENTORY", 22, " ")
```

**7. Show a machine id to the player without a second list.**

```
On ability unlocked
  -> set AbilityLabel text = As Title Text(ability_id)
```

`fire_sword` reads `Fire Sword`. Ids and labels can no longer drift apart, because there is only one
of them.

**8. Raise the first letter of a generated line, and leave the rest alone.**

```
On pickup
  -> set LogLabel text = As Sentence Text(log_line)
```

`picked up an HP potion` reads `Picked up an HP potion` - the `HP` keeps its capitals, which
Uppercase and Lowercase would both destroy.

**9. A translated sentence with a value in it - the correct order.**

```
On coins changed
  -> CoinLabel: Set Text (translated pattern)  "You have {coins} coins", {"coins": coins}
```

It emits:

```gdscript
text = tr("You have {coins} coins").format({"coins": coins})
```

The key that goes in your catalog is the whole pattern, `{coins}` included.

**10. The same, as an expression you can compose.**

```
On quest completed
  -> set BannerLabel text = Translated Text From Pattern("Quest complete: {title}", {"title": quest_title})
```

**11. Re-run every translated label on a language switch.**

```
On Language Changed
  -> CoinLabel: Set Text (translated pattern)  "You have {coins} coins", {"coins": coins}
```

Without this, a label filled once at startup keeps the old language until the scene reloads.

**12. Catch a clipped button while you are still authoring.**

```
Every tick
  Condition: StartButton  Text Overflows
    -> log "START button overflows in " + TranslationServer.get_locale()
```

Turn on Clip Text on the button first, or it grows to fit and honestly answers false.

**13. Ask about a control from somewhere else.** Both pixel rows that act on a control take an
**On node** parameter, so one watchdog row can check a button it is not attached to.

```
Every tick
  Condition: Text Overflows  On node: $UI/Menu/StartButton
    -> tint the button red
```

**14. Fix the overflow instead of only reporting it.**

```
On Ready
  -> QuestTitleLabel: Fit Text To Label  "..."

On Language Changed
  -> QuestTitleLabel: Fit Text To Label  "..."
```

The second row re-fits from the original string, not from the first row's leftovers.

**15. Check a string fits BEFORE the control exists.**

```
On menu built
  Condition: Text Fits In Width  tr("MENU_START"), 180, ThemeDB.fallback_font, 16   (inverted)
    -> widen the button to 240
```

Feed it a translated string. The source English always fits, which is exactly why nobody catches
this.

**16. Grow a dialogue panel to whatever the line needs.**

```
On dialogue line shown
  -> set DialoguePanel size.y = Wrapped Text Height(tr(line_key), 220, ThemeDB.fallback_font, 16) + 24
```

**17. Stop a Japanese build drawing empty boxes.**

```
On Ready
  -> Add Font Fallback  ThemeDB.fallback_font, load("res://fonts/noto_cjk.ttf")
```

It is idempotent, so putting it in On Ready AND under On Language Changed costs nothing.

**18. Prove the fallback worked, in the editor, without reading Japanese.**

```
On Ready
  Condition: Font Can Show  ThemeDB.fallback_font, tr("MENU_START")   (inverted)
    -> log "Missing glyphs for MENU_START in " + TranslationServer.get_locale()
```

**19. Ask about the font a label is really drawing with.**

```
Every tick
  Condition: Font Can Show  TitleLabel.Font Of This Control, TitleLabel.text   (inverted)
    -> log "TitleLabel cannot draw its own text"
```

Font Of This Control follows theme overrides and Use Font rows, so the check is about what is on
screen rather than about a font you named twice.

**20. Mirror the whole UI for Arabic and Hebrew.**

```
On Ready
  -> UIRoot: Mirror Layout For Language
```

**21. Flip a hand-placed slide-in with it.**

```
On panel opens
  Condition: Panel  Layout Is Mirrored
    -> tween Panel position.x from -400 to 0
  Else
    -> tween Panel position.x from 400 to 0
```

Godot mirrors containers and anchors for you; this is for the positions you set yourself.

**22. Branch on the language rather than on a control.**

```
On Ready
  Condition: Language Reads Right To Left
    -> use the mirrored menu artwork
```

### Other use cases

**Debug overlay.** Align Left the stat names and Align Right the numbers in a monospace Label, and a
dozen live values become a readable table with no Control per row.

**Chat name column.** Shorten To Whole Words each speaker name to a fixed budget so a long handle can
never push the message text out of alignment.

**Steam-style playtime.** As Duration over a saved second count gives `12h 04m` without a single
division written by hand.

**Store-page screenshot pass.** A Text Overflows watchdog row over each menu button, logged once per
locale, turns "check every language by hand" into a list you read off the output panel.

**Data-asset labels.** As Title Text over the id column of a resource grid gives every entry a
player-facing name for free, so the grid never has to carry a second column that drifts.

## Tips and common mistakes

- **Overflow only answers honestly on a control that cannot grow.** A Label or Button free to widen
  is grown by the engine to fit, so Text Overflows returns false and Fit Text To Label has nothing to
  do. Turn on Clip Text, set a Text Overrun Behavior, or use a fixed-size container.
- **Text Overflows measures ONE line.** For a label that wraps, compare Wrapped Text Height against
  the box height instead.
- **Measure the TRANSLATED string, not the key and not the English.** Text Fits In Width and Font Can
  Show take whatever you hand them; hand them `tr(...)`. The rows that read a control's own text
  already do this lookup for you.
- **Translate first, fill second.** Translating the OUTPUT of Text From Pattern looks up a string
  with the values already baked in, which no catalog can contain, so the label never translates.
  Use Translated Text From Pattern (or the Set Text action) and keep the pattern - slots and all - as
  the catalog key.
- **The columns only line up in a monospace font.** Align Left, Align Right and Center In Width pad
  by CHARACTER count. In a proportional font the edges still drift, however correct the padding is.
- **The column expressions never cut.** Text longer than the width is left exactly as it is, so a long name
  breaks the column. Shorten it first, then align it.
- **Fill is one character.** Godot pads with the first character of what you give it.
- **With Thousands Separators drops the fraction.** It is whole numbers only, by design. It is also a
  plain-float expression: for idle-game scale (`1.23e15`, `1.23 Qa`) the Big Numbers pack has its own
  formatters.
- **As Percent Text wants a 0-to-1 fraction.** Handing it a 0-to-100 value produces `7300%`.
- **As Clock Time and As Duration are different expressions on purpose.** As Clock Time is strict `mm:ss`
  and rolls an hour into `60:00`; As Duration switches to `1h 02m`. Pick the one whose failure mode
  you can live with.
- **Both Shorten expressions can return text with no ending on it.** When the width cannot hold the ending
  at all, the text wins and the marker is dropped - which is what guarantees the result is never
  wider than the width you asked for, and never just an ellipsis.
- **Add Font Fallback needs a fallback that resolves to the SAME resource every run.**
  `load("res://fonts/...")` does; `SystemFont.new()` builds a new object each time and would stack up
  in the chain. Left empty, the row deliberately does nothing.
- **`fallbacks` has to be assigned back**, which is why the template rebuilds the array rather than
  appending to it. Do not "simplify" a hand-written version to an in-place append - the font never
  rebuilds the chain it draws with.
- **Use Font on a RichTextLabel needs the right slot.** RichTextLabel ignores the main `font` item
  entirely and keeps four separate faces, which is why the Slot parameter is a list.
- **Fit Text To Label remembers the string it was given.** That is the feature, not a leak: it lives
  in the node's `fit_source_text` meta so a language switch re-fits the whole sentence. If you assign
  a genuinely new source string to the label, that meta is what the next fit will start from.
- **Mirror Layout For Language earns its keep where something PINNED a direction.** A project left on
  the default already mirrors an untouched control; the row is what hands a pinned control (or a
  pinned ancestor) back to the language.
