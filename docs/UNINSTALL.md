# Removing Godot EventSheets without breaking your game

The plugin's core promise is **zero runtime dependency**: every sheet compiles to plain,
typed GDScript that references no EventForge/EventSheet class, so a shipped game keeps
running after the plugin is gone. This guide makes that removal safe and deliberate.

A CI test (`tests/clean_removal_test.gd`) enforces this contract on every push: it parses
every generated script *with the plugin's `class_name`s off the path* and scans for any
banned `EventForge*` / `EventSheet*` / `EventForgeBridge` symbol. If that test is green,
the removal below is safe.

## Recommended order

1. **Run the doctor / eject check while the plugin is still installed.**
   Dock → **Tools → Eject EventSheets…** (or headless `godot --headless --script tools/eject.gd`).
   It recompiles every sheet, fails loudly on any drift, and reports exactly what to keep.
   Do not proceed until it reports **safe**.
2. **Disable the plugin** (Project → Project Settings → Plugins → Godot EventSheets → off),
   or just delete the addon folders — `_exit_tree` cleanly removes the autoload, the
   inspector/export/debugger plugins, the context menus, and the main-screen editor.
3. **Delete** `addons/eventforge/` and `addons/eventsheet/`.
4. **Remove the `EventForgeBridge` autoload** if it is still listed (Project Settings →
   Autoload). It is editor-only — nothing in a shipped game needs it.
5. Done. Your game runs on the generated scripts alone.

## Keep vs. remove

| Keep (your game needs these) | Remove (plugin-only) |
|---|---|
| `*_generated.gd` — the compiled scripts your scenes attach | `addons/eventforge/` |
| `eventsheet_addons/**/*.gd` — behavior packs are plain `class_name` classes the game uses | `addons/eventsheet/` |
| Your **autoload-sheet singletons** (they point at compiled `.gd`, not at the plugin) | The **`EventForgeBridge`** autoload (editor-only vocabulary) |
| Generated scenes (`.tscn`) and resources | The legacy `.tres` sheet sources, if any (optional — default `.gd` sheets stay editable as plain code; a `.tres` is only needed to re-edit those specific sheets) |

The one subtlety: an **autoload sheet** registers a singleton pointing at its *compiled*
`.gd`. That singleton stays — deleting it would break your game. Only the plugin's own
`EventForgeBridge` autoload is removed.

## Re-installing later

Drop `addons/eventforge/` + `addons/eventsheet/` back in and re-enable the plugin. The
`.tres` sources (if you kept them) re-open as sheets; any `.gd` opens as a GDScript-backed
sheet. Nothing was lost — the code was always the source of truth.
