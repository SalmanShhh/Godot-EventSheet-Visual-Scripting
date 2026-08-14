# Translating Your Game

Event sheets translate the Godot way: mark the text that players see, and Godot's own
localisation pipeline does everything else. There is no plugin string table and no export
step of its own - a sheet compiles to a plain `.gd`, Godot's POT generator reads the `tr()`
calls straight out of that file, translators fill in a catalog, and `TranslationServer`
swaps languages live. Delete the plugin and your translated game still runs.

![A string parameter in the apply dialog with the globe toggle lit next to it - the value ships wrapped in tr("...") for Godot's POT generation and TranslationServer](images/translation-globe.png)

Contents:

1. [Scenarios where this excels](#1-scenarios-where-this-excels)
2. [Mark the text players see](#2-mark-the-text-players-see)
3. [Generate the translation template (POT)](#3-generate-the-translation-template-pot)
4. [Add a language](#4-add-a-language)
5. [Switch languages from events](#5-switch-languages-from-events)
6. [Sentences with slots: translate first, fill second](#6-sentences-with-slots-translate-first-fill-second)
7. [The Translation vocabulary](#7-the-translation-vocabulary)
8. [Use cases](#8-use-cases)
9. [Tips and common mistakes](#9-tips-and-common-mistakes)

## 1. Scenarios where this excels

- **A jam game that ships in two languages**: mark five strings with the globe, paste a
  four-line CSV, add a language toggle button - done in minutes.
- **A dialogue-heavy game**: writers work in the sheet, the POT template collects every
  marked line automatically on regenerate, translators never open Godot.
- **A live language switcher in the options menu**: one Set Language action; every
  auto-translated Control and later `tr()` lookup follows instantly.

## 2. Mark the text players see

Any plain text field in the parameters dialog has a small globe button beside it. Toggle
it on and the value ships wrapped in `tr("...")` at its usage site:

```gdscript
print(tr("Spawned"))          # globe ON
label.text = str(tr("READY")) # globe ON, via Set Text
```

The globe stays dim until lit - most parameters (node paths, group names, amounts) are
not player-facing text and should stay unmarked. Reopening a marked value shows the plain
text with the globe lit; toggling it off unwraps it.

For text built at runtime (a variable holding a key, a formatted message), use the
**Translate** expression instead of the globe - it is the same `tr()` call with an
expression argument.

## 3. Generate the translation template (POT)

Godot extracts translatable strings from scripts - and a sheet IS a script:

1. Open **Project Settings > Localization > POT Generation**.
2. **Add** your compiled sheet files (the `.gd` the sheet saves to).
3. Press **Generate POT** and choose where to write the template.

The template lists every `tr("...")` string from your sheets. Regenerate it whenever you
add text; existing translations are unaffected.

## 4. Add a language

Two common routes, both plain Godot:

- **CSV (fastest)**: create `strings.csv` in your project:

  ```csv
  keys,en,es
  Spawned,Spawned,Aparecido
  READY,Ready!,Listo!
  ```

  Godot imports it automatically and produces one `.translation` file per column. Add
  those files under **Project Settings > Localization > Translations**.
- **gettext (.po)**: hand the generated POT to translators; import the returned `.po`
  files the same way.

That registration step is what makes `tr()` return translated text. The Project Doctor
reminds you if sheets translate text while the project has no catalog registered yet.

## 5. Switch languages from events

- **Set Language** action with a locale code (`"en"`, `"es"`, `"ja"`) switches the whole
  game live: auto-translated Controls re-render, and every later `tr()` lookup uses the
  new language.
- **On Language Changed** runs an event whenever the language switches - refresh any text
  you built manually there (re-assign labels from `tr()` expressions). The trigger adds
  its "Language Just Changed" gate condition for you; leave it in place.
- **Current Language** returns the active locale code, e.g. to highlight the current
  choice in an options menu.

## 6. Sentences with slots: translate first, fill second

Most player-facing text has a value in the middle of it: "You have 7 coins", "Ilsa: hello",
"Chapter 3 of 12". The natural way to build that is the shipped **Text From Pattern**, and the
natural way to translate it is to wrap the result in **Translate**. That combination silently does
not work, and it is worth understanding exactly why:

```
Translate(Text From Pattern("You have {coins} coins", {"coins": 7}))
```

Text From Pattern runs first, so `tr()` is handed `"You have 7 coins"` - a string that appears in no
catalog, because a catalog holds the PATTERN, not one filled-in instance of it. The lookup misses,
`tr()` returns its argument unchanged, and the label reads in the source language forever. Nothing
errors and nothing warns; the text is simply never translated.

Two verbs do it in the order that works - look the whole sentence up FIRST, fill the slots second:

- **Translated Text From Pattern** (Expression, folder **Translation**) - emits
  `tr(pattern).format(values)`.
- **Set Text (translated pattern)** (Action, folder **Translation**) - the Label twin of the same
  thing.

```
Function   On refresh_hud
  -> Set Text (translated pattern)   "You have {coins} coins"   with   {"coins": coins}
  -> Set Text of "Wallet"   Translated Text From Pattern("{name}: {amount}", {"name": wallet_name, "amount": amount})

On Language Changed
  -> Call Function   refresh_hud()

Has Changed   coins
  -> Call Function   refresh_hud()
```

Three things follow from this:

- **The pattern IS the key.** `You have {coins} coins`, braces and all, is the exact line that goes in
  your CSV or POT - so a translator sees the slot and can move it, which is the whole point in a
  language with a different word order.
- **Re-run it on a language change.** A Label filled from an expression is not auto-translated by
  Godot, so refresh it under **On Language Changed** (the example above routes both the language
  switch and the value change through one function).
- **The slot names travel.** `{coins}` must survive translation. A translator who renames the slot
  breaks the fill, so keep slot names short and obviously technical.

## 7. The Translation vocabulary

| ACE | Kind | Emits |
|---|---|---|
| Set Language | Action | `TranslationServer.set_locale(locale)` |
| Current Language | Expression | `TranslationServer.get_locale()` |
| Translate | Expression | `tr(text)` |
| Translate With Context | Expression | `tr(text, context)` |
| Translate Plural | Expression | `tr_n(singular, plural, count)` |
| Translated Text From Pattern | Expression | `tr(pattern).format(values)` |
| Set Text (translated pattern) | Action | `text = tr(pattern).format(values)` |
| Language Just Changed | Condition | `what == NOTIFICATION_TRANSLATION_CHANGED` |
| On Language Changed | Trigger | the `_notification` virtual + the gate above |

Context disambiguates strings that read the same but translate differently ("May" the
month vs the verb). Plural picks the right form for a count per language, including
languages with more than two plural forms.

Everything AROUND the lookup has vocabulary of its own, grouped by the problem it solves:

| Group | Verbs | The problem |
|---|---|---|
| The menu that builds itself | For Each Language, Language Name In Its Own Language, Language Is Available, Use Saved Language | A language list that rots one hand-written button at a time |
| Matching, not comparing | Language Matches, Region Is, Value For Language, Current Language Name, Country Name | `Current Language == "en"` is wrong for every player on en_US |
| Following a switch | Set Text (follows language), Refresh Text That Follows Language, Keep This Text Untranslated | Godot re-renders text a Control still HOLDS; text an event wrote stays in the old language |
| Finishing a plural | Counted Text, Counted Text From Pattern, Set Text (counted) | The chosen form still carries its `%d` |
| Surviving a missing key | Text Is Translated, Language Has Text For, Translated Text Or Fallback, Test With Fake Translation | `tr()` hands the key back, and the player reads `MENU_TITLE` |
| Gendered and player-named lines | Translated Text From Pattern In Context, Translated Text With Words | One key holding a masculine, feminine and neutral translation |
| Numbers the locale can read | Number In Local Digits, Number From Local Digits, Percent Sign, Date Parts | Arabic-Indic digits, a language's own percent sign, and a date order the translator owns |
| Coverage, before release | Translation Coverage, Missing Translation Keys, Translation Is Complete | An export gate that fails loudly on a half-finished language |
| Files, voice and data cells | Localized File, Load For Language, Say Line, Has Voice For Language, Voice Line Length, Reading Time Of, Translated Field Of, Translated Column Of Table | The parts of a localised game that are not strings |
| The drawn side | Language Reads Right To Left, Mirror Layout For Language, Layout Is Mirrored, Add Font Fallback, Use Font, Font Of This Control, Font Can Show, Text Overflows, Fit Text To Label, Text Fits In Width, Wrapped Text Height | Right-to-left layout, missing glyphs, and German that does not fit the button |

**A note on plurals and CSV catalogs.** Godot takes the plural RULE from the locale (Russian
has three forms) but the FORMS from the catalog, and a CSV catalog stores `%d apple` and
`%d apples` as two ordinary rows with one form each. Counted Text handles both: with a CSV
catalog the count picks between the two translated rows, and with a gettext (.po) catalog it
uses all the forms that catalog carries. If a language needs its third form to read
correctly, ship that language as a `.po`.

## 8. Use cases

### 1. A jam game in two languages by Sunday

Mark the dozen player-facing strings with the globe as you write them, export the POT, paste translations from a friend, done - the sheet logic never changes.

### 2. Dialogue marked translatable at author time

Every queued line or shown message gets the globe toggle when typed, so "we'll localise later" never becomes an archaeology project.

### 3. A language switcher in the pause menu

One Set Language action per button ("English", "Deutsch", "Espanol") - labels re-resolve live, no restart.

### 4. Plurals done right

"%d coin" vs "%d coins" (and languages with more than two forms) go through the plural-aware ACE instead of an `if count == 1` that only works in English.

### 5. One word, two meanings

"Close" the door vs "Close" the menu: contexts keep the two entries separate so translators see which is which.

### 6. Handing off mid-project

Export the POT at any point - the translator works while you keep adding events; new strings join the next export without disturbing finished entries.

### 7. A CJK build for a storefront launch

Shipping to a Japanese storefront means the menu, tutorial prompts, and item names all need `tr()` and a font that covers the glyphs; mark the strings once in the sheet and one `strings.csv` column carries every translated line without touching your event logic.

### 8. Community-sourced translations

Point your Discord volunteers at the exported POT and merge back the `.po` files they return - each language is just another catalog registered under Localization, so a Brazilian-Portuguese pack from a fan drops in without a single sheet edit.

### 9. Debug overlay stays in one language

Your FPS counter, coordinate readout, and console log are for you, not players, so you leave their globes dim - only the strings a real player reads get marked, and the POT never fills with developer noise.

### 10. Right-to-left languages for a jam theme

Adding Arabic or Hebrew as a stretch goal means registering an RTL catalog and letting Godot mirror layout; the sheet side is unchanged because every player string already flows through `tr()` and re-resolves on the Set Language switch.

### 11. Weekend patch adds a fifth language

A community offers a Polish translation after launch: you regenerate the POT, hand it over, register the returned catalog, and add one more Set Language button - the shipped game needs no recompile of hand-written systems because the sheet already emits plain `tr()` calls.

### 12. Plural and context in the same shop line

An in-game store shows "1 gem" versus "5 gems" and reuses "Free" for both price and shipping; the plural-aware ACE handles the count and Translate With Context keeps the two "Free" entries apart so translators are never guessing.

## 9. Tips and common mistakes

- **Never wrap a variable's DEFAULT in tr()**. Defaults initialize before translations
  load, and `@export` defaults are data, not display text. Mark the text where it is
  USED (the globe lives on usage-site parameters for exactly this reason).
- **The POT scan reads the compiled `.gd`** - add the sheet's saved script file to POT
  Generation, not a `.tres`.
- **Keys vs sentences**: both work. `tr("READY")` with catalog entries per language keeps
  source text stable; `tr("Press any key")` reads better in the sheet. Pick one style per
  project.
- **Controls often need no code at all**: Labels and Buttons with auto-translate enabled
  translate their `text` property by themselves - the globe is for text your EVENTS
  produce.
- **Do not mark node paths, group names, animation names, or action names** - translating
  identifiers breaks lookups. The globe defaults to off for a reason.
- **Test a language quickly**: add a Set Language action on a debug key press, or set
  Project Settings > Internationalization > Locale > Test to force one at startup.
- **Never fill a sentence's slots before translating it.** `Translate(Text From Pattern(...))` looks
  up a string that already has your values in it, which no catalog contains, so the label stays in
  the source language and nothing warns. Use **Translated Text From Pattern** (or the Set Text twin),
  which translates the pattern first and fills second.
