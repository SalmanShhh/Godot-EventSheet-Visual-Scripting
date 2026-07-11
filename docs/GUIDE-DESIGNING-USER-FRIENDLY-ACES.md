# Designing User-Friendly ACEs

How to design Actions, Conditions, and Expressions that non-programmers can find, understand,
and use correctly on the first try. The craft here is the one Construct-style editors proved
over a decade: the vocabulary IS the user interface. A sheet author never reads your
implementation - they read your verb's name in the picker, your one-sentence description, your
parameter labels, and the sentence the finished row renders as. Those four surfaces are the
product; the GDScript behind them is plumbing.

This guide is design advice. The mechanics of registering ACEs live in
[GUIDE-CUSTOM-ACES.md](GUIDE-CUSTOM-ACES.md) (annotations on scripts and packs) and
[GUIDE-CREATING-CUSTOM-MODULES.md](GUIDE-CREATING-CUSTOM-MODULES.md) (descriptor modules);
everything below applies to both channels.

## Table of Contents

1. [The four surfaces a user actually sees](#the-four-surfaces-a-user-actually-sees)
2. [Rule zero: rows must read as sentences](#rule-zero-rows-must-read-as-sentences)
3. [Naming verbs](#naming-verbs)
4. [Choosing the kind: action, condition, expression, trigger](#choosing-the-kind-action-condition-expression-trigger)
5. [Parameters: few, labelled, defaulted, and picked - not typed](#parameters-few-labelled-defaulted-and-picked---not-typed)
6. [Descriptions that answer "when would I use this?"](#descriptions-that-answer-when-would-i-use-this)
7. [Progressive disclosure: featured, hidden, sections, synonyms](#progressive-disclosure-featured-hidden-sections-synonyms)
8. [Behavior patterns worth copying](#behavior-patterns-worth-copying)
9. [The code your ACE compiles to is also UI](#the-code-your-ace-compiles-to-is-also-ui)
10. [A worked redesign](#a-worked-redesign)
11. [Checklist before you ship](#checklist-before-you-ship)

---

## The four surfaces a user actually sees

When someone uses your ACE, they meet it in this order:

1. **The picker entry** - display name + category + kind colour. Won it or lost them here.
2. **The description panel** - your one sentence. It must answer "is this the one I want?"
3. **The parameter dialog** - labels, defaults, per-param blurbs, and the field WIDGETS
   (dropdowns, pickers, capture buttons). This is where wrong values happen or don't.
4. **The finished row** - the display template rendered with their values inline. They will
   re-read this a hundred times while debugging; it has to still make sense next month.

Design all four deliberately. An ACE with a perfect implementation and a lazy display name is
a bad ACE.

## Rule zero: rows must read as sentences

The display template (the last argument of `make_descriptor`, or the row text your function's
name generates) is rendered in the sheet with parameter values substituted in. Write it so the
finished row reads aloud as plain English:

```
Good:  rebind {action} to {physical_keycode}     ->  "rebind "jump" to KEY_SPACE"
Good:  {button} is down                          ->  ""MOUSE_BUTTON_LEFT" is down"
Good:  set {action} deadzone to {deadzone}       ->  "set "ui_right" deadzone to 0.2"

Bad:   InputRebind({action},{physical_keycode})  (reads as code)
Bad:   deadzone                                  (which action? set to what?)
```

Put the parameters INSIDE the sentence at the spot where a human would say them. If you cannot
write the template as a sentence, the ACE is probably doing too many things - split it.

## Naming verbs

- **Actions start with a verb**: Set, Add, Start, Stop, Clear, Restore, Rebind, Shake, Capture.
  The pair matters: everything a user can Start they will look for a Stop for
  (Start Head Bob / Stop Head Bob), everything Set has a reader (the expression), everything
  Capture has a Release.
- **Conditions read as claims**: "Is Crouching", "Mouse Is Captured", "Action Is Bound",
  "Anything Is Pressed". A condition name should drop into the sentence "run these actions
  when ___" without editing.
- **Triggers start with On**: "On Landed", "On Slide Started", "On Shake Stopped". Name the
  moment, not the mechanism ("On Landed", never "On is_on_floor Edge").
- **Expressions name the value**: "Current Speed", "Mouse Velocity", "Gamepad Name",
  "Action Binding As Text". No verb - it IS a thing.
- **Name the user's idea, not the engine's API.** `Input.is_physical_key_pressed` becomes
  "Key Is Down". `InputMap.load_from_project_settings()` becomes "Restore Default Bindings" -
  the name of the button on every options menu, which is what the user is building.
- **Say which flavour when there are two.** Event-scoped conditions carry the "(event)"
  suffix - "On Key Pressed (event)" - so the polling twin ("Key Is Down") and the event twin
  cannot be confused. Same for spaces: "Mouse Position (world)" / "(screen)" / "(local)".
- **The category is the noun.** Categories group by what the user is thinking about (Mouse,
  Keyboard, Gamepad, Juice, Sine), never by implementation (never "InputMap Utilities Misc").
  A user building a rebind screen should find everything in one or two neighbouring sections.

## Choosing the kind: action, condition, expression, trigger

Pick the kind by how the user THINKS about the moment, not by what the code does:

- Something the game should DO -> **action**.
- A question with a yes/no answer -> **condition**.
- A value to display, compare, or feed into a parameter -> **expression**.
- A moment the game should REACT to -> **trigger** (a signal). If your behavior detects
  something (a landing, a wall touch, a finished tween), emit a signal and mark it a trigger -
  do not make users poll a condition every tick for an edge they will miss.
- **State or event?** "Is Sliding" (state, condition) and "On Slide Started" (event, trigger)
  are both worth shipping - they answer different questions. When a fact has interesting
  edges, ship the pair.
- **Stateful conditions** (the descriptor API's `.stateful(member, prelude, on_true)`) let a
  condition carry per-row memory - this is how Trigger Once and Every X Seconds work. Reach for
  it when the friendly meaning needs an edge or a timer the user should not have to build.
- **Fire-and-forget beats configure-then-run.** An action should complete a whole user
  intention in one row: "Rebind Action To Key" erases AND binds; "Zoom To Position" glides AND
  frames. If using your feature takes three rows in a fixed order, fold them into one verb and
  keep the granular verbs for experts.

## Parameters: few, labelled, defaulted, and picked - not typed

Every parameter is a chance to go wrong. Spend design effort here:

- **Two or three params, rarely more.** Past that, split the ACE or move rarely-touched
  settings to Inspector knobs on the behavior (exported variables get automatic Set/Add/read
  ACEs, so they stay scriptable).
- **Every param has a display name and a one-line description.** The description shows as the
  tooltip AND under the field. Say the unit and the range: "Stick travel ignored before the
  action registers, 0 to 1."
- **Defaults make the dialog open USABLE.** The user should be able to press OK immediately
  and get sensible behavior (Shake opens at 0.4, Recoil at -90, 12). A default is
  documentation: it teaches the value's scale.
- **Pick, don't type.** The plugin has a field widget for almost every kind of value - use the
  hint that matches, because a picked value cannot be misspelled:

| The param is... | Use |
|---|---|
| an existing input action | hint `input_action` (a LIVE picker of the project's Input Map) |
| a keyboard key | hint `key_capture` (press-a-key capture, no keycode tables) |
| one of a fixed set | `options` (a dropdown; `{"key": ..., "label": ...}` entries let the menu read friendly while inserting real code) |
| a suggestion, but free text allowed | `autocomplete` (an editable filter-combo) |
| a sheet variable / signal / enum member | hint `variable_reference` / `signal_reference` / `enum:Name` |
| a node's method / property / animation | hint `method_reference` / `property_reference` / `animation_reference` (reflected pickers) |
| a colour / scene / audio file | hint `color` / `scene_path` / `audio_path` |
| a position or size | a Vector2/Vector3 default - the dialog splits it into per-axis fields |
| genuinely any expression | hint `expression` (the field grows the fx picker button) |

- **Enum params carry the meaning in the value.** `@export_enum("sine", "triangle", "square")`
  and String options like "reach" / "nearest" read in the row; magic ints (`mode = 2`) never do.
- **Accept the obvious unit.** Degrees, seconds, pixels, percent - whatever the user would say
  out loud. Convert to radians and fractions inside the template
  (`sin(deg_to_rad({degrees}))`), never in the user's head.

## Descriptions that answer "when would I use this?"

`.described("...")` (or the doc comment above a pack function - it becomes the description
automatically) is one sentence, maybe two. The formula that works:

> **What it does, in outcome words** + **the situation you would use it in.**

Real examples from the bundled vocabulary:

- "Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays
  automatically - fire it on every hit."
- "How far a stick must move before the action counts - the drift-vs-responsiveness slider
  every controller options menu needs."
- "True while ANY key, mouse button, or gamepad input is held - press-any-key screens and
  idle detection."

Notice what these do NOT do: name engine classes, restate the display name, or say "this
function". They describe the game situation. If your description is "Sets the deadzone of the
action", you have written the display name twice and helped nobody.

Warnings go in the description too, plainly: "needs an active Camera3D", "use inside an
On Input event", "cosmetic - aim is untouched".

## Progressive disclosure: featured, hidden, sections, synonyms

A useful pack has thirty verbs; a beginner needs five. The plugin gives you channels to serve
both without hiding either:

- **`.featured()`** (or `@ace_featured` on a pack function): the handful of verbs a first-time
  user should meet - they render bold and float up the picker. Feature the verbs that
  demonstrate the pack's point ("Rebind Action To Key", "Restore Default Bindings"), not the
  plumbing. If you feature more than a quarter of your verbs, you have featured nothing.
- **`@ace_hidden`**: internal helpers that must exist as functions but mean nothing to a sheet
  author (`_wave`, `_can_stand_up`). Hide them; a picker entry that cannot be used correctly
  is noise.
- **Section descriptions** (`section_descriptions()` on a module, or
  `EventSheets.register_section_description`): the blurb shown when a picker section header is
  selected. One sentence on what lives in the drawer: "Create and rebind controls, and read
  movement as a vector or axis."
- **Quick-add synonyms** (`EventSheets.register_quick_add_synonyms`): the words users will
  actually type. If your verb is "Shake" but people type "screen shake", "rumble", or
  "earthquake", teach the search those phrases - discovery is part of the design.
- **Tags** (`@ace_tags(camera, juice)`): searchable in the picker and filterable over MCP -
  cheap cross-category discovery for verbs that belong to a theme.

## Behavior patterns worth copying

Patterns from the bundled packs that consistently make ACEs feel effortless:

- **Safe to spam.** Actions that can fire every frame or on every hit without bookkeeping:
  Shake ADDS trauma and clamps; Recoil kicks STACK and recover on their own. The user never
  writes "if not already shaking".
- **The finish trigger.** Every fire-and-forget effect emits "On X Finished" (zoom, squash,
  slowmo, lean). That one signal turns your action into a sequencing primitive - users chain
  beats reactively instead of guessing durations with timers.
- **State verbs hold, event verbs recover.** "Lean" eases to an angle and STAYS (a state, the
  user leans back explicitly); "FOV Punch" kicks and returns by itself (an event). Decide which
  one your verb is and say so in the description - mixing the two is the most common source of
  "why is my camera stuck".
- **Never-fails modes.** Where an operation can fail (no path to the target), offer the mode
  that degrades gracefully ("nearest" instead of "reach") and a trigger for the failure
  ("On Path Failed") - failure handling becomes a row, not a crash.
- **Auto-find, allow override.** The Juice packs find the active camera themselves; "Use
  Camera" pins a specific one. Zero wiring for the 95% case, full control for the rest. Same
  shape everywhere: sensible automatic behavior + one explicit override verb.
- **Whole-step verbs.** "Rebind Action To Key" is erase + create + bind in one action, because
  "rebind" is one THOUGHT. Ship the granular verbs too (Clear Action Bindings, Bind Event To
  Action) for the experts building custom flows.
- **Derive, don't ask.** The pathfinding design reads jump physics off the sibling movement
  behavior instead of asking the user to re-type numbers that already exist. If another node
  already knows the answer, read it - and provide the override verb for unusual setups.
- **Exported knobs are free ACEs.** On packs, every exported variable automatically publishes
  Set / Add To / Subtract From / read verbs. Put feel-tuning (speeds, amplitudes, decay rates)
  in exported knobs rather than parameters - the Inspector, the sheet, AND the picker all get
  them, in one declaration.

## The code your ACE compiles to is also UI

Sheets compile to plain GDScript the user can open, read, and keep forever (the parity
promise). Your codegen template is therefore a fifth surface:

- **Emit the code a careful human would write.** `Input.warp_mouse({position})` is what a
  Godot programmer would type; a wrapper call into your library is not. Readable output is
  what makes "open the generated script and learn from it" work.
- **One statement when possible; `{uid}` locals when not.** Multi-line templates use
  `__name_{uid}` for temporaries so two copies of the row never collide. The `{uid}` is baked
  when the row is applied in the editor - your template just uses it.
- **Deterministic, always.** No timestamps, no randomness in emission. The same sheet must
  produce the same bytes every compile - that is what makes diffs reviewable and the byte
  round-trip gate possible.
- **Guard inside the template when misuse is likely.** "Remove Input Action" wraps itself in
  `if InputMap.has_action(...)` - one row, no crash on a double-remove. Cheap safety inside
  the template beats an error message the user has to interpret.
- **Frozen once shipped.** `ace_id`s and codegen templates are compatibility promises - sheets
  in user projects reference them forever. You can improve display names and descriptions
  freely; to change behavior, ship a NEW id and deprecate the old one (mark it deprecated; it
  keeps compiling). Design like you only get one shot at the id, because you do.

## A worked redesign

The same feature, designed twice. Feature: let sheets tune stick sensitivity.

**First draft (what the engine API suggests):**

```
Action:  SetDeadzone(action: String, value: float)
Display: "SetDeadzone {action} {value}"
Description: "Sets the deadzone."
Param action: type String, no default, no hint.
Param value: type float, no default.
```

Every surface fails. The picker entry is a code identifier. The description restates the name.
The dialog opens empty; the user must know an action name by heart and guess the value scale
(0..1? 0..100?). The finished row reads "SetDeadzone jump 0.2" - code, not a sentence.

**Shipped version:**

```
Action:  "Set Action Deadzone"   (category: Input)
Display: "set {action} deadzone to {deadzone}"
Description: "How far a stick must move before the action counts - the
              drift-vs-responsiveness slider every controller options menu needs."
Param action:   hint input_action (a live picker of the project's actions), default "ui_right".
Param deadzone: default 0.2, description "Stick travel ignored before the action
                registers, 0 to 1."
```

Same template underneath (`InputMap.action_set_deadzone({action}, {deadzone})`). Every surface
now works: findable name, a description that names the situation, a dialog that opens usable
with nothing typed, and a row that reads "set "move_left" deadzone to 0.2" - a sentence.

## Checklist before you ship

- [ ] Read every display template aloud with real values substituted. Sentences?
- [ ] Open each parameter dialog and press OK without typing. Sensible result?
- [ ] Does every param that CAN be picked use the matching hint / options / autocomplete?
- [ ] Does every description answer "when would I use this?" without naming engine classes?
- [ ] Start/Stop, Capture/Release, Set/read - are the pairs complete?
- [ ] Are the 3-6 hero verbs `.featured()` and the internals `@ace_hidden`?
- [ ] Do fire-and-forget actions emit an On X Finished trigger?
- [ ] Is the action safe to run twice in a row (guard inside the template if not)?
- [ ] Would you sign off on the emitted GDScript in a code review?
- [ ] `EventSheets.verify_pack(...)` passes (parses + byte round-trips) and the suite is green.
- [ ] Are you happy with the `ace_id` forever? It freezes at release.
