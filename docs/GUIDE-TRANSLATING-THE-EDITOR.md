# Translating the editor into your language

The event sheet editor speaks English by default, and every piece of its interface - buttons,
menus, tooltips, dialogs, the getting-started screens - can be translated by dropping in one
plain CSV file. No code, no registration step, no rebuild.

This page is about translating the EDITOR itself. Translating your GAME's text (the strings
your sheets show players) is a different feature - see GUIDE-TRANSLATING-YOUR-GAME.md.

## Add a language in three steps

1. **Create the file.** Make a folder called `eventsheet_translations` at your project root
   (next to `project.godot`) and put a CSV file in it - any name, for example `french.csv`:

   ```csv
   keys,fr
   Save,Enregistrer
   Add Event,Ajouter un événement
   Add Condition,Ajouter une condition
   ```

   - The first column is the English text exactly as the editor shows it.
   - Every other column is one language, named by its locale code in the header
     (`fr`, `es`, `pt_BR`, `ja`, ...). One file can carry many languages.
   - A cell you leave empty simply keeps its English text - translate at your own pace.

2. **Pick the language.** Open Tools → Welcome… - the Preferences card has an
   **Editor language** dropdown, and every language your files provide is already in it
   (the list refreshes each time the Welcome opens). English (default) is always first.

3. **There is no step 3.** The choice applies live and is remembered per user, per project -
   it never touches your project files or version control.

## Getting the full list of English strings

Run the extraction tool and it writes a ready-to-fill template containing every string the
editor currently shows:

```
"$GODOT" --headless --path . --script tools/extract_editor_strings.gd
```

Output: `eventsheet_translations/eventsheet_editor_strings.template.csv` - rename the second
column's header to your locale code and start filling cells. A starter with the most common
strings also ships at `addons/eventsheet/translations/TEMPLATE.csv`.

A complete worked example ships with the plugin: `addons/eventsheet/translations/fr.csv` is a
French translation of the everyday surface (toolbar, menus, dialogs, the getting-started
screens, the tour). It is why **Français** already appears in the language dropdown - and the
file to copy when starting your own language.

## Where translation files are picked up

Both folders are scanned, so your translations survive plugin updates:

- `res://eventsheet_translations/` - YOUR files, at the project root (recommended).
- `res://addons/eventsheet/translations/` - files bundled with the plugin.

Ready-made Godot `Translation` resources (`.translation` / `.tres`) in those folders work
too; their `locale` property names the language.

## For addon and extension authors

Everything you show through a Control (a dialog you build, a button you add) translates
automatically - the whole dock shares one translation domain. For the rest:

- `EventSheets.translate(text)` - translate any string you draw or format yourself. It is a
  pass-through in English, so calling it costs nothing and makes the string translatable
  forever. Route every user-facing string of a new feature through it.
- `EventSheets.register_translation_file(path)` - ship translations WITH your pack (any
  folder), merged live into the language catalogs.
- `EventSheets.available_languages()` / `EventSheets.set_editor_language(locale)` - the
  picker's plumbing, exposed.

Your ACE `display_name`s, descriptions, and Custom Block kind titles already flow through the
translation layer in the picker and menus - shipping a CSV whose keys are those English names
localises your whole pack. **Never translate ids** (`ace_id`, `kind_id`, provider ids): they
are compatibility contracts; only display strings localise.

## The rules the system keeps for you

- **English is the default.** A fresh install shows English; no file, no setting needed.
- **English is the fallback.** An untranslated (or newly added) string shows its English
  source instead of a blank or a key.
- **Dropping in a file IS the registration.** If a file provides a locale, the language
  picker offers it. Deleting the file removes it.
- **Your language choice is personal.** It lives in your per-user editor state, never in the
  project - teammates each pick their own.
