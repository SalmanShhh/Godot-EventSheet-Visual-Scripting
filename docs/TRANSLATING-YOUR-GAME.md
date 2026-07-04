# Translating Your Game

Event sheets translate the Godot way: mark the text that players see, and Godot's own
localisation pipeline does everything else. There is no plugin string table and no export
step of its own - a sheet compiles to a plain `.gd`, Godot's POT generator reads the `tr()`
calls straight out of that file, translators fill in a catalog, and `TranslationServer`
swaps languages live. Delete the plugin and your translated game still runs.

Contents:

1. [Scenarios where this excels](#1-scenarios-where-this-excels)
2. [Mark the text players see](#2-mark-the-text-players-see)
3. [Generate the translation template (POT)](#3-generate-the-translation-template-pot)
4. [Add a language](#4-add-a-language)
5. [Switch languages from events](#5-switch-languages-from-events)
6. [The Translation vocabulary](#6-the-translation-vocabulary)
7. [Tips and common mistakes](#7-tips-and-common-mistakes)

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

## 6. The Translation vocabulary

| ACE | Kind | Emits |
|---|---|---|
| Set Language | Action | `TranslationServer.set_locale(locale)` |
| Current Language | Expression | `TranslationServer.get_locale()` |
| Translate | Expression | `tr(text)` |
| Translate With Context | Expression | `tr(text, context)` |
| Translate Plural | Expression | `tr_n(singular, plural, count)` |
| Language Just Changed | Condition | `what == NOTIFICATION_TRANSLATION_CHANGED` |
| On Language Changed | Trigger | the `_notification` virtual + the gate above |

Context disambiguates strings that read the same but translate differently ("May" the
month vs the verb). Plural picks the right form for a count per language, including
languages with more than two plural forms.

## 7. Tips and common mistakes

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
