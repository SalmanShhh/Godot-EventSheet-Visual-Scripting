---
name: suggest-new-eventsheet-vocabulary
description: Generate an HTML mockup of 15+ code-pattern suggestions for EventSheets in the settled sheet design language - each with event-sheet rows, the editor click path, and the code (@ace_*) authoring route. Use when the user asks for pattern/vocabulary suggestions for a theme (game feel, tool dev, UI, a genre) as a visual mockup.
---

# Suggest new event sheet vocabulary (as a visual mockup)

Produce ONE self-contained HTML file mocking up pattern suggestions for the theme given in
the arguments (e.g. "tool dev experience", "juice and game feel", "roguelike vocabulary").
Default to 15-20 suggestions unless the user asks for a different count. Write the file to
the session's temporary folder (never into the repo) and send it to the user with SendUserFile
(display: render). Build only after this file's rules are satisfied - the user picks from
the mockup before anything is implemented.

## 1. Survey FIRST (non-negotiable)

Before inventing any vocabulary, grep the repo so nothing already-shipped is presented as
new, and so authoring snippets use REAL names:

- `addons/eventforge/registration/modules/*.gd` - builtin ACE vocabulary (ace_ids AND
  display names; both must be collision-checked before minting).
- `tools/pack_builders/*.gd` - how packs author ACEs in code.
- `addons/eventsheet/api/eventsheets.gd` - the public API (register_simple_ace,
  register_doctor_check, register_palette_command, register_editor_preview,
  register_editor_gizmo, register_asset_drop_handler, register_row_menu_item, ...).
- `docs/GUIDE-CUSTOM-ACES.md` - the real annotation set: @ace_name, @ace_description,
  @ace_category, @ace_condition, @ace_action, @ace_trigger, @ace_expression,
  @ace_looping(iterator), @ace_codegen_template, @ace_param(name, hint:, default:,
  options:), @ace_expose_all, @ace_hidden.
- `addons/eventsheet/editor/dock/menu_bar.gd` + `context_menus.gd` - real menu labels for
  click paths.
- Any theme-relevant guides in `docs/` (e.g. GUIDE-EDITOR-TOOLS.md for tool-dev themes).

Tag every suggestion honestly: green "NEW VERBS" (pure vocabulary), blue "NEEDS EDITOR
SEAM" (requires new plugin support), gray "EXTENDS EXISTING" (a seam exists - name the
file/API it extends). Proposed-but-nonexistent menu items must read as proposals.

## 1b. Every suggestion passes the two models BEFORE it is drawn

Two audits of past mockups found the same defects over and over; state the rules up front and
mark each suggestion against them, so the reader sees compliance instead of being told.

**The condition/action model (the lane):** branching is a condition in the left lane; an
effect is an action in the right; a value is an expression inside a cell; iteration is a loop
row; nesting mirrors the emitted code; an `if` is never action-lane text; outcomes are read
back as conditions or triggers, never as a side-channel variable. Never draw a loop or a
run-once gate in the action lane over a filler "Always" condition - it goes on the left.

**The ACE model on Godot (the kind):** a trigger IS a Godot signal and fires when something
happens; a condition is a bool check; an action is an effect; an expression is a value. If a
suggestion says "when X happens", it is a signal-backed trigger, and its payload rides the
signal arguments as row context - not a polled condition and not a variable. If a real signal
exists, prefer it over a polled check (the reactive-alternative rule). Per-key or per-verb
variants are one signal with the key as payload/parameter, not N signals. Debugger and
diagnostic information is never program text: it lives in the gutter, a panel, or the game
overlay, and only when asked for.

Tag every suggestion beside its tier: `MODEL: clean / reshaped` and `KIND: ok / signal-true /
re-kinded`, and put a compact audit table after the intro. Reshape in place rather than cut
where the idea is sound and only the shape is wrong.

## 2. Each suggestion shows THREE things

1. **The rows**: how the pattern reads as event-sheet rows (condition lane | action lane).
2. **Author via eventsheets**: the click path, as `<span class="ui">Menu > Item</span>`
   chips inside an `.author` box labeled "HOW YOU'D AUTHOR IT (EDITOR)".
3. **Author via code**: a small GDScript snippet (doc-comment @ace_* annotations, or an
   EventSheets.register_* call, or a pack-builder descriptor) in a second `.author` box
   labeled "HOW YOU'D AUTHOR IT (CODE)" with a `<pre>` block.

Group suggestions under h2 headers (A., B., C., ...) with the tier tag beside the title.

When a suggestion touches gameplay or content (anything a shipped pack could serve), add a
fourth section: a compact "WORKS WITH (EXISTING PACKS)" box (green left border, small-caps
label) holding 2-5 chips - each a REAL pack display name (verify the builder exists in
`tools/pack_builders/`) plus a few words on the division of labor ("Dialogue Kit - plays
the lines this authors"). The point is pairing with shipped packs instead of reinventing
them; only list pairings that genuinely make sense.

## 3. The settled sheet design language (follow EXACTLY)

CSS tokens:

```
--bg:#191d22; --panel:#21262d; --lane:#262c35; --lane2:#2b323c; --border:#39414d;
--text:#d8dde4; --dim:#8b94a1; --object:#d8a35a; --verb:#eceff3; --value:#9fd47a;
--kw:#6db3f2; --comment:#98a0ac; --accent:#4f8fdd; --new:#58c08a; --code:#c7cdd6;
```

Body font "Segoe UI", code in Consolas. Rules that are part of the project's grammar:

- Event rows are two lanes: condition cell (44%, `--lane`) left, action cells
  (`--lane2`) right, hairline `--border` between and around.
- Every condition/action cell has an OBJECT sub-column ("System", "Editor", "self") with a
  hairline separator, then the sentence. All separators in a lane ALIGN at one shared x.
- Object labels are orange (`--object`), verbs bold near-white (`--verb`), typed values
  green (`--value`).
- Kind cues are 15px square badges in a narrow badge column, NEVER words-in-boxes (no word
  pills): blue square = condition ACE, purple #7a63c9 = action, round green = trigger,
  italic "f" = computed check.
- An `if` is ALWAYS a condition cell in the left lane - never action-lane text.
- Structure mirrors code: nesting renders as indented sub-events.
- `.author` boxes: left 3px #5a6b82 border, background #1e232a, small-caps dim label.

## 4. House rules

- NO em-dashes anywhere in the file - use " - ".
- No absolute personal paths (no C:\Users\<name>\...).
- Self-contained HTML: no external fonts, scripts, or images.
- Deliver with SendUserFile (display: render) and summarize in chat: the suggestion list,
  which existing features overlap (with file paths), and which suggestions need seams.
- Do NOT start implementing any suggestion - wait for the user to pick.
