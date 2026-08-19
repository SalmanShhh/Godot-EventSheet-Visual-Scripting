# Localising Your Game

**Translation** is the built-in vocabulary for shipping in more than one language. It is a thin layer
over Godot's own localisation runtime: `TranslationServer` swaps locales, `tr()` and `tr_n()` look up
the current language, and **Project Settings > Localization** owns the catalogs. Nothing here adds a
runtime, so every row compiles to a bare native call and keeps working after the plugin is removed.

What the vocabulary adds is everything *around* the lookup, in the order a shipped game meets it: a
language menu that builds itself from the catalogs the build actually ships, matching a locale instead
of comparing it, text that follows a live language switch, plurals that finish the sentence, missing
keys that are visible instead of silent, numbers and dates written the way the language writes them,
a catalog-health gate you can put in an export bake step, and the content that is not a string at all:
per-language files, voice clips with captions that cannot out-run them, and data cells that hold keys.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [Reference tables](#reference-tables)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A language menu that builds itself** from the catalogs the build shipped, in each language's own name.
- **A live language switch** with no scene reload and no per-label wiring.
- **Regional players** treated as speakers of their language, not as special cases.
- **Plurals** that read "3 apples" rather than "%d apples", in languages with two forms and with three.
- **Half-finished catalogs** that fall back readably instead of showing a raw key.
- **Gendered and player-named lines** without an if-chain per sentence.
- **Numbers and dates** in the digits and the order the language uses.
- **Build gates** that refuse to ship a release with an unfinished shipped language.
- **Localised assets** - a translated sign, a font with the right glyphs, a re-lettered scene.
- **Voice with subtitles** that stay up exactly as long as the line, dubbed or not.
- **Data-driven content** where one `.tres` serves every language.

## Core concepts

- **The catalog is a spreadsheet.** Godot's CSV shape: the first line is the column names, the first
  column is the source string (its header cell is ignored, so it is usually spelled `keys`), and every
  other column is one language. A `.po` gettext catalog works too and can carry more plural forms.
- **A missing key is not an error.** `tr()` hands the key straight back, so the player reads
  `MENU_TITLE` and nothing warns. Three rows make that visible: **Text Is Translated**, **Language
  Has Text For** and **Translated Text Or Fallback**.
- **Match, do not compare.** `compare_locales` scores a pair of locales from 0 to 10, so `pt_BR`
  against `pt` scores 5. **Language Matches** is true for an `en_US` player asked about `en`, which a
  string comparison against **Current Language** is not.
- **Godot re-renders text a Control still holds.** Text a sheet computed and assigned does not follow
  a language switch, which is why half the screen changes and half does not. **Set Text (follows
  language)** remembers the key on the node, and **Refresh Text That Follows Language** re-applies
  every remembered key in one row.
- **Some text is data, not writing.** A player's name, a chat line, a save-slot label. **Keep This
  Text Untranslated** stops Godot auto-translating a Control and everything under it.
- **A plural form still carries its `%d`.** **Translate Plural** returns the chosen form as it stands;
  **Counted Text** is the one that fills the number in.
- **Only languages with a catalog are listed.** **For Each Language** walks
  `TranslationServer.get_loaded_locales()`, so English usually appears only when it has a catalog of
  its own.
- **A language variant of a file sits beside it.** `sign.ja.png` next to `sign.png`. **Localized
  File** and **Load For Language** resolve exact locale first, then language-only, then the base file.

## Setup

Add your `.csv` (or `.po`) in **Project Settings > Localization > Translations**. Then the smallest
useful sheet is a language button and a refresh:

```
On language button pressed
  -> set language to "de"
  -> save game/language = "de"

On language changed
  Condition: language just changed
    -> refresh text that follows the language
```

And on startup, restore last time's pick:

```
On Ready
  -> use the saved language, otherwise OS.get_locale()
```

## Reference tables

On the canvas these read as sentences with the values in bold, exactly as the rows draw them:

- set language to **"de"**
- language matches **"pt"**
- **3** as counted text
- say **"ilsa.greet.01"** with its subtitle

### Switching, reading and reacting to the language

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Language | Switches the game's language live. | `TranslationServer.set_locale({locale})` |
| Use Saved Language | Applies the language the player picked last time, falling back on a first run. | a three-line `ConfigFile` block reading `user://settings.cfg`, section `game`, key `language` |
| Current Language | The active locale code, e.g. `"en"`. | `TranslationServer.get_locale()` |
| Current Language Name | The active language written out in English. | `TranslationServer.get_locale_name(TranslationServer.get_locale())` |
| Language Name In Its Own Language | That language's name as its own speakers write it. | a guarded read of the locale's own `LANGUAGE_NAME` message, falling back to `TranslationServer.get_locale_name({locale})` |
| Language Is Available | True when a catalog for that language is registered in this build. | `TranslationServer.has_translation_for_locale({locale}, false)` |
| For Each Language | Runs the actions once per language the build ships. Read the current one as `language`. | a loop over `TranslationServer.get_loaded_locales()` |
| Language Matches | True when the game runs in that language, region or not. | `TranslationServer.compare_locales(TranslationServer.get_locale(), {locale}) > 0` |
| Region Is | True when the active locale names that country. | a capitals check plus `Array(TranslationServer.get_locale().split("_")).slice(1).has({country})` |
| Country Name | Turns a country code into its readable English name. | `TranslationServer.get_country_name({country})` |
| On Language Changed | Runs when the language switches. | the `_notification` virtual, with the gate condition added for you |
| Language Just Changed | The gate under On Language Changed. | `what == NOTIFICATION_TRANSLATION_CHANGED` |

### Looking text up

| Name | What it does | Ships as |
|------|--------------|----------|
| Translate | Looks the text up in the current language. | `tr({text})` |
| Translate With Context | The same, with a context that disambiguates identical strings. | `tr({text}, {context})` |
| Translate Plural | Picks the singular or plural form for a count, as it stands. | `tr_n({singular}, {plural}, {count})` |
| Counted Text | Picks the form AND fills the number into it. | the two-branch form chooser followed by `.replace("%d", str(int({count})))` |
| Counted Text From Pattern | The same, filling named `{slots}` instead of a `%d`. | the form chooser followed by `.format({values})` |
| Translated Text From Pattern In Context | Looks a whole sentence up with a context, then fills its slots. | `tr({pattern}, {context}).format({values})` |
| Translated Text With Words | Fills a translated sentence from a standing word set plus this line's values. | `tr({pattern}).format({words}.merged({values}, true))` |
| Translated Text Or Fallback | Looks the key up and falls back when the language has no entry. | `(tr({key}) if tr({key}) != {key} else {fallback})` |
| Value For Language | Picks the entry of a record whose language best matches the player's. | a `reduce` over `{choices}.keys()` scored by `compare_locales`, with `{fallback}` |
| Text Is Translated | True when the active language has text for this key. | `tr({key}) != {key}` |
| Language Has Text For | Asks one named language's catalog directly, without switching to it. | `has_translation_for_locale({locale}, true)` and a non-empty `get_translation_object({locale}).get_message({key})` |

### Labels that follow the language

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Text (follows language) | Sets a Label's text AND remembers the key on the node. | `set_meta(&"follows_language_key", {key})`, `add_to_group(&"follows_language", true)`, `text = tr({key})` |
| Set Text (counted) | Sets a Label to the counted sentence in one row. | `text = ` plus the same form chooser and `%d` fill as Counted Text |
| Refresh Text That Follows Language | Re-applies every remembered key in the current language. | a loop over the `follows_language` group re-reading each node's meta |
| Keep This Text Untranslated | Stops Godot auto-translating this Control and its children. | `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED` |

### Numbers and dates

| Name | What it does | Ships as |
|------|--------------|----------|
| Number In Local Digits | Writes a number in the digits the language uses. | `TranslationServer.format_number(str({value}), {locale})` |
| Number From Local Digits | Turns digits the player typed back into plain ASCII ones. | `TranslationServer.parse_number({text}, {locale})` |
| Percent Sign | The percent sign the language writes. | `TranslationServer.get_percent_sign({locale})` |
| Date Parts | A date broken into `{year}`, `{month}`, `{day}`, `{hour}`, `{minute}`, `{second}`, `{weekday}`. | `Time.get_datetime_dict_from_unix_time(int({unix}))` |

### Is the catalog actually finished?

| Name | What it does | Ships as |
|------|--------------|----------|
| Translation Coverage | How much of the spreadsheet that language fills, 0 to 100. | a lambda over the parsed `.csv` rows, counting unfilled cells, 0.0 for an empty file |
| Missing Translation Keys | The list of source strings that language has NOT filled, in file order. | the same parse, filtered to unfilled rows and mapped to their first column |
| Translation Is Complete | True only when every source string has a filled cell for that language. | "has rows AND none of them are unfilled" over the same parse |
| Test With Fake Translation | Turns Godot's pseudolocalization on, so unmarked strings stay plain. | `TranslationServer.set_pseudolocalization_enabled({on})` |

The three catalog rows share three parameters: `locale` (the column heading, spelled exactly as it
appears in the file), `path` (the `.csv`), and `separator`.

### Content that is not a string

| Name | What it does | Ships as |
|------|--------------|----------|
| Localized File | The path that exists for the player's language, or the base file. | a lambda resolving `<name>.<locale>.<ext>`, then `<name>.<language>.<ext>`, then the base path |
| Load For Language | Loads that variant. | `load(...)` around the same resolution |
| Say Line | Plays the key's clip in the player's language and holds the translated caption for exactly as long as it runs. | a block that resolves the clip, writes `tr({key})` onto the caption node, then either awaits a reading-time timer or plays the clip and awaits `finished`, and clears the caption either way |
| Has Voice For Language | True when the player's language ships a clip for this key. | `not <resolved clip path>.is_empty()` |
| Voice Line Length | How many seconds this key's clip runs in the player's language, 0.0 when there is none. | the resolution, loaded, then `get_length()` when it is an `AudioStream` |
| Reading Time Of | How long a caption of that length should stay up, with a floor. | `maxf({minimum_seconds}, {text}.length() / maxf({chars_per_second}, 1.0))` |
| Translated Field Of | Reads a record's field as a translation key. | a lambda over `{record}.get({field})` returning `tr(str(...))`, or `""` for null |
| Translated Column Of Table | A whole column read as translated text, in row order. | `{table}.map(...)` around the same field read |

The voice rows take `key` (the line's name, which is both the catalog key and the clip's file name),
`folder` (one subfolder per language inside it) and `extension` (the clip format). **Say Line** adds
`caption` (the label the subtitle lands on, or null for voice with no caption) and an **On node**
target so the row can point at any `AudioStreamPlayer`.

## Use cases

**1. A language button.** Switch and remember, so the next run opens in the same language.

```gdscript
func _on_german_pressed() -> void:
	TranslationServer.set_locale("de")
```

Pair it with a **Save Setting** row writing section `game`, key `language`, and **Use Saved Language**
picks it up next launch.

**2. Restore last time's language on startup.** The fallback is the system locale, which is the
friendly first-run answer.

```gdscript
func _ready() -> void:
	var __lang_cfg_boot01 = ConfigFile.new()
	__lang_cfg_boot01.load("user://settings.cfg")
	TranslationServer.set_locale(str(__lang_cfg_boot01.get_value("game", "language", OS.get_locale())))
```

**3. A language menu that builds itself.** **For Each Language** walks the catalogs the build shipped,
so a language you add later joins the menu with no sheet edit.

```
On Ready
  -> For Each Language
      -> add a button labelled Language Name In Its Own Language(language)
      -> when it is pressed: set language to language
```

The label reads "Deutsch" rather than "German" as long as each catalog carries a `LANGUAGE_NAME` row
(`LANGUAGE_NAME,Deutsch,Espanol`). Without that row it falls back to Godot's English name, and
without a catalog of its own to the bare code, so an entry is never blank.

**4. Hide a language a demo build did not ship.** **Language Is Available** matches the way Godot
matches, so a build that ships `pt_BR` answers true for `"pt"` as well.

```
On Ready
  Condition: "es" is available
    -> show the Spanish button
```

**5. Branch content on the language, not on the exact locale.**

```gdscript
if TranslationServer.compare_locales(TranslationServer.get_locale(), "ja") > 0:
	show_vertical_layout()
```

This is true for `ja` and for any regional variant of it. Comparing **Current Language** to `"ja"` by
hand is right for exactly one spelling and wrong for every other.

**6. A region-gated screen.** **Region Is** is for the imprint page, the age gate, the storefront
link, not for translation. `pt_BR` is region `BR`; plain `pt` is no region at all.

```
On open legal screen
  Condition: region is "DE"
    -> show the imprint page
```

**7. Name the region on screen.** **Country Name** turns the code into words.

```gdscript
label.text = TranslationServer.get_country_name("BR")
```

**8. Text that follows a live switch.** This is the pair that fixes the half-switched screen.

```gdscript
func _ready() -> void:
	set_meta(&"follows_language_key", "MENU_TITLE")
	add_to_group(&"follows_language", true)
	text = tr("MENU_TITLE")
```

Then one row under **On Language Changed** re-applies every remembered key at once:

```
On language changed
  Condition: language just changed
    -> refresh text that follows the language
```

**9. Protect text that is data.** A save slot named "Play" must not turn into "Jouer" because a
catalog happens to contain that word.

```gdscript
func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
```

**10. A counted sentence that reads correctly.** **Counted Text** picks the form for the count AND
fills the number in, so `"%d apple"` / `"%d apples"` reads "3 apples".

```
Every tick
  -> set BasketLabel text = Counted Text("%d apple", "%d apples", basket_count)
```

**11. Set a Label's counted line in one row.** **Set Text (counted)** is the same sentence as a single
action, with nothing to nest. Re-run it under **On Language Changed** so it follows a live switch.

**12. A counted sentence carrying more than the count.** **Counted Text From Pattern** lets the
language pick the form first and the slots fill after, so a translator can move `{n}` and `{total}`
where their grammar wants them.

```
Every tick
  -> set ProgressLabel text = Counted Text From Pattern("{n} chapter left", "{n} chapters left", left, {"n": left})
```

**13. A gendered line.** The context is an expression, so it can be a variable read at runtime, and one
key can hold masculine, feminine and neutral translations.

```gdscript
label.text = tr("{name} is ready.", speaker_gender).format({"name": hero_name})
```

**14. A player-named, player-gendered character.** Keep the pronouns in one variable and every line
follows a change to it.

```gdscript
label.text = tr("{name} drew {their} sword.").format(character_words.merged({"name": hero_name}, true))
```

**15. Never show a raw key.** **Translated Text Or Fallback** covers the half-finished catalog, and
chains: put another one in the Otherwise field.

```gdscript
label.text = (tr("TUTORIAL_HINT") if tr("TUTORIAL_HINT") != "TUTORIAL_HINT" else tr("HINT_GENERIC"))
```

**16. Offer a language only when the screen is actually translated.** **Language Has Text For** asks
one catalog directly, without switching to it, and counts a translation identical to its source.

```
On Ready
  Condition: "ja" has text for "TUTORIAL_HINT"
    -> enable the Japanese button
```

**17. Find unmarked strings before a translator does.** Pseudolocalization comes back accented and
bracketed, so anything still plain ASCII is a string nobody marked.

```gdscript
func _ready() -> void:
	if OS.is_debug_build():
		TranslationServer.set_pseudolocalization_enabled(true)
```

**18. A per-language splash, voice folder or currency shape, in one row.** **Value For Language**
picks the entry that best matches, so a `pt_BR` player gets the `"pt"` entry.

```
On Ready
  -> set Splash.texture = Value For Language({"ja": JP_SPLASH, "zh": CN_SPLASH}, DEFAULT_SPLASH)
```

The row emits a `reduce` over the record's keys, scored by `compare_locales`, and reads the winning
entry out of the dictionary. An entry that scores nothing leaves the fallback standing, so an unlisted
language is never a wrong pick.

**19. Local digits, both ways.** Write a number in the player's numerals, and read one back from a
field they typed into.

```gdscript
extends Node


quantity_label.text = TranslationServer.format_number(str(1234), TranslationServer.get_locale())
var typed := TranslationServer.parse_number(quantity_field.text, TranslationServer.get_locale())
```

**20. A date the translator owns.** **Date Parts** hands the catalog the pieces, so `DATE_FORMAT`
reads `{month}/{day}/{year}` in English and `{day}.{month}.{year}` in German without a build.

```gdscript
date_label.text = tr("DATE_FORMAT").format(Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system())))
```

**21. A build gate that refuses to ship half-translated.** Put **Translation Is Complete** under **On
Project Export** beside **Export Has Feature** `"release"`, inverted.

```
On project export (bake step)
  Condition: the export has feature release
  Condition: "fr" is fully translated  (inverted)
    -> print Missing Translation Keys("fr", "res://i18n/strings.csv", ",")
```

An empty, missing or unreadable catalog is never "complete", so a mistyped path fails the build
loudly rather than passing it.

**22. A per-language report at File > Run.** **Translation Coverage** is a number and **Missing
Translation Keys** is the list, so a tool sheet can print both per language from a For Each Language.

**23. A translated sign, font or scene.** Name the variant beside the base file and nothing else has
to change.

```
On language changed
  Condition: language just changed
    -> set Sign.texture = Load For Language("res://art/sign.png")
```

It is one row: **Load For Language** on `res://art/sign.png`, which resolves
`sign.<locale>.png`, then `sign.<language>.png`, then the base file. Run it under **On Language
Changed**, because a `preload` freezes its choice when the script loads and never follows a switch.

**24. Dub it if we have it, subtitle it if we do not.** **Say Line** already does both, and holds the
caption for the clip's length or for the line's reading time.

```
On dialogue line
  -> say "ilsa.greet.01" with its subtitle
```

**25. Branch on whether a dub exists.** **Has Voice For Language** is the explicit gate when the
dubbed and undubbed paths differ in more than timing.

```
On dialogue line
  Condition: there is a voice line for "ilsa.greet.01" in this language
    -> play the portrait animation
```

**26. Pace a cutscene off the audio.** **Voice Line Length** answers 0.0 for a language with no clip,
so a Wait built on it does not stall a subtitle-only build.

**27. How long should a toast stay up?** **Reading Time Of** answers for any text, translated or not,
with a floor so a two-word line is not a flash.

```gdscript
await get_tree().create_timer(maxf(1.2, tr("TOAST_SAVED").length() / maxf(14.0, 1.0))).timeout
```

**28. One data asset, every language.** **Translated Field Of** reads a field as a key, so a quest,
a price entry or a storylet needs no column per locale.

```
On quest started
  -> set QuestTitle text = Translated Field Of(quest, "title")
```

It is safe on a pack that still stores plain English in that cell: an entry no catalog contains comes
back exactly as it was written.

**29. A whole column as words.** **Translated Column Of Table** fills a dropdown, a quest log or a
shop list in row order, and a row missing that field contributes empty text rather than dropping out,
so the list stays the same length as the table.

### Other use cases

**A pseudolocalized layout pass.** Turn Test With Fake Translation on in a debug build and turn Project Settings > Internationalization > Pseudolocalization length expansion up, and any panel that will overflow in German overflows here, weeks before the German arrives.

**An accessibility subtitle build.** Ship no voice folder at all and Say Line still holds every caption for its own reading time, so the whole dialogue system doubles as a subtitles-only mode with no second code path.

**A localised storefront page.** Value For Language picks a screenshot set and Region Is picks the legal footer, so one scene serves every market without a per-region duplicate.

**A translator handover report.** A tool sheet that walks For Each Language printing Translation Coverage and Missing Translation Keys gives a translator a to-do list keyed by the exact source strings.

**A community translation drop.** Because Language Is Available and For Each Language read the catalogs at runtime, a player-supplied catalog added to Project Settings shows up in the menu with no code change at all.

## Tips and common mistakes

- **Translate Plural is not the finished sentence.** It returns the chosen form with its `%d` still in
  it, which is why a label built from it reads "%d apples". **Counted Text** is the one that fills the
  number.
- **Keep the `%d` in both plural forms.** A translation that drops it comes back unfilled, and nothing
  errors, because the fill is a `replace` rather than a `%` format. That is deliberate: a `%` on a
  form the translator broke would raise once per evaluation, which under Every Frame is once a frame.
- **A CSV catalog has two plural forms, not three.** Godot's CSV importer stores `"%d apple"` and
  `"%d apples"` as two ordinary keys with one form each, so **Counted Text** picks between the two
  translated keys directly. A `.po` catalog carrying three Russian forms uses all three. Both are
  handled; you do not choose.
- **Language Is Available is fuzzy; Language Has Text For is exact.** A build shipping `pt_BR` answers
  true for `"pt"` on the first and false for `"pt_PT"` on the second. Use the exact one when you mean
  one named catalog.
- **A translation identical to its source reads as untranslated** to **Text Is Translated**, because
  the check is "did `tr()` change the string". Use **Language Has Text For** when that matters.
- **`tr()` on a computed string does not follow a switch.** The moment a sheet looks a key up and
  assigns the result, that node stops following the language. That is the whole reason **Set Text
  (follows language)** and **Refresh Text That Follows Language** exist.
- **Set Text (follows language) takes plain keys only.** For a sentence with values in it, use the
  translated-pattern expressions and re-run them from a function under On Language Changed.
- **Region Is wants capitals.** The country code is checked against its own uppercase form, which is
  what stops a script subtag (the `Hans` in `zh_Hans`) from being mistaken for a country. Plain `pt`
  has no region and answers false.
- **A missing catalog file scores 0, never 100.** **Translation Coverage** and **Translation Is
  Complete** treat an unreadable path as unfinished on purpose, so a typo fails an export gate loudly
  instead of shipping a half-translated game while the gate reports success.
- **A cell holding only spaces counts as unfilled.** A translator who left a space has not translated
  the line.
- **Number In Local Digits does not group thousands.** It changes digits only; a language Godot has no
  digit set for comes back unchanged, which is most of them, so it is safe to leave on everywhere.
- **Use Saved Language reads `user://settings.cfg`, section `game`, key `language`.** Write the same
  three with a Save Setting row on the button that switches, or nothing is remembered.
- **A `preload` never follows a language switch.** **Load For Language** must run at run time. Put it
  under On Language Changed as well as on ready.
- **A voice folder is per language, not per locale.** `voice/en/`, `voice/ja/`. A player on `de_AT`
  counts the `de` folder as theirs; a language with no folder is subtitle-only, and **Voice Line
  Length** answers 0.0 for it.
- **Say Line reads its caption expression once**, at the moment the line starts, so nothing can
  re-point it half way through and leave a caption stranded on screen.
