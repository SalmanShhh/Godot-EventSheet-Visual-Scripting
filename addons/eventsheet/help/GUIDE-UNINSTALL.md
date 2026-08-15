# Removing Godot EventSheets Without Breaking Your Game

The plugin's core promise is **zero runtime dependency**: every sheet compiles to plain, typed GDScript that references no EventForge/EventSheet class, so a shipped game keeps running after the plugin is gone. This guide makes that removal safe and deliberate: how the contract is enforced, the order to remove things in, exactly what to keep, and how to come back later.

## Table of Contents

1. [How the Contract Is Enforced](#1-how-the-contract-is-enforced)
2. [Recommended Removal Order](#2-recommended-removal-order)
3. [Keep vs Remove](#3-keep-vs-remove)
4. [Re-installing Later](#4-re-installing-later)
5. [Scenarios Where Clean Removal Matters](#scenarios-where-clean-removal-matters)
6. [Tips and Common Mistakes](#5-tips-and-common-mistakes)

---

## 1. How the Contract Is Enforced

A CI test (`tests/clean_removal_test.gd`) enforces the zero-runtime-dependency contract on every push: it parses every generated script *with the plugin's `class_name`s off the path* and scans for any banned `EventForge*` / `EventSheet*` / `EventForgeBridge` symbol. If that test is green, the removal below is safe.

---

## 2. Recommended Removal Order

1. **Run the doctor check while the plugin is still installed.**
   Dock → **Tools → Project Doctor…** (or headless `godot --headless --path . --script tools/project_doctor.gd`).
   It recompiles every sheet, fails loudly on any drift, and reports exactly what to keep.
   Do not proceed until it reports **safe**.
2. **Disable the plugin** (Project → Project Settings → Plugins → Godot EventSheets → off),
   or just delete the addon folders - `_exit_tree` cleanly removes the autoload, the
   inspector/export/debugger plugins, the context menus, and the main-screen editor.
3. **Delete** `addons/eventforge/` and `addons/eventsheet/`.
4. **Remove the `EventForgeBridge` autoload** if it is still listed (Project Settings →
   Autoload). It is editor-only - nothing in a shipped game needs it.
5. Done. Your game runs on the generated scripts alone.

---

## 3. Keep vs Remove

| Keep (your game needs these) | Remove (plugin-only) |
|---|---|
| `*_generated.gd` - the compiled scripts your scenes attach | `addons/eventforge/` |
| `eventsheet_addons/**/*.gd` - behavior packs are plain `class_name` classes the game uses | `addons/eventsheet/` |
| Your **autoload-sheet singletons** (they point at compiled `.gd`, not at the plugin) | The **`EventForgeBridge`** autoload (editor-only vocabulary) |
| Generated scenes (`.tscn`) and resources | The legacy `.tres` sheet sources, if any (optional - default `.gd` sheets stay editable as plain code; a `.tres` is only needed to re-edit those specific sheets) |

The one subtlety: an **autoload sheet** registers a singleton pointing at its *compiled* `.gd`. That singleton stays - deleting it would break your game. Only the plugin's own `EventForgeBridge` autoload is removed.

---

## 4. Re-installing Later

Drop `addons/eventforge/` + `addons/eventsheet/` back in and re-enable the plugin. The `.tres` sources (if you kept them) re-open as sheets; any `.gd` opens as a GDScript-backed sheet. Nothing was lost - the code was always the source of truth.

---

## Scenarios Where Clean Removal Matters

- **The jam is over and you are handing off the `.zip`.** A judge or teammate opens your project with no plugin installed; because every sheet already compiled to plain GDScript, the game boots and plays exactly as it did on your machine, with zero "missing addon" errors.
- **A client or publisher forbids third-party editor plugins in the delivered build.** You author everything with EventSheets, run Project Doctor, delete `addons/eventforge/` and `addons/eventsheet/`, and ship a repo that contains only stock Godot and your own generated `.gd` - the contract test proves nothing plugin-shaped leaked into runtime.
- **You are trimming the git repo before a public open-source release.** Removing the two addon folders drops tens of thousands of editor-only lines from the tree while your gameplay scripts stay byte-identical, so the published project is lean and self-contained.
- **A teammate on the project does not run the editor at all - they only touch code.** They pull, and the compiled sheets plus behavior packs under `eventsheet_addons/` are just ordinary classes to them; they never install the plugin and never hit a wall because of it.
- **You are evaluating EventSheets on a real project and want an exit ramp before committing.** Because removal is reversible and the code was always the source of truth, you can pull the plugin out mid-evaluation, confirm the game still runs untouched, and drop it back in later with nothing lost.
- **CI builds the shipping game on a machine that never had the editor plugin.** The headless export runs against the generated scripts alone; there is no autoload to register and no `EventForgeBridge` to resolve, so the pipeline stays clean and fast.

## 5. Tips and Common Mistakes

- **Run Project Doctor first, every time.** It recompiles every sheet and fails loudly on drift. Do not delete anything until it reports **safe**.
- **Do not delete your autoload-sheet singletons.** They point at compiled `.gd` files, not at the plugin; removing them breaks the game. The only autoload that goes is `EventForgeBridge`, which is editor-only.
- **Behavior packs stay.** Everything under `eventsheet_addons/` is plain `class_name` GDScript the game uses at runtime; it is not part of the plugin.
- **Legacy `.tres` sources are optional to keep.** Default `.gd` sheets stay editable as plain code; a `.tres` is only needed if you want to re-edit those specific sheets after re-installing.
- **Removal is reversible.** The code was always the source of truth, so re-installing the plugin recovers full sheet editing with nothing lost.
