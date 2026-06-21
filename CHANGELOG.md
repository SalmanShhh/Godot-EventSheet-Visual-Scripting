# Changelog

## [Unreleased]

### Added
- **Node paths are validated as you type, with `$` autocomplete.** Expression fields (every node-reference
  param, including the new "On node" target) now flag a node reference that does not exist in the edited
  scene — `$Enmy`, `get_node("UI/Scrore")` — in amber with a "no node here yet" tooltip, so a typo is
  caught at author time instead of failing silently in the running game. It is a *warning*, not an error:
  a path may legitimately point at a node spawned at runtime. Typing `$` also offers the scene's node
  paths as completions, so a path can be typed-and-picked, not only chosen through the 🔍 picker.
- **Node-scoped ACEs can target another node now.** Every host-scoped node ACE (Set Modulate, Set
  Volume, Play Animation, Set Camera Zoom, Set Label Text, the particle/joint/range/button setters — 180+
  in all) gained an optional **"On node"** field: leave it blank to act on this node as before, or pick a
  node / type a path (`$Enemy`, `get_node("UI/Score")`) to redirect the whole operation to another node.
  This is powered by a new covenant-safe codegen idiom, the optional-prefix `{target.}` (a blank value
  emits nothing, so existing sheets compile **byte-for-byte unchanged** — verified by the drift audit),
  and the importer round-trips both shapes (`play()` and `$Enemy.play()`) back to the same ACE. The
  spawn-a-new-node and already-targeted ACEs (e.g. Play Sound At, the Joint body setters) are left as-is.
- **Group aggregate expressions** — roll a numeric member up across a whole group with no loop: **Sum
  In Group**, **Average In Group**, **Lowest In Group**, **Highest In Group** (joining the existing
  Count Nodes In Group, under the **Groups** category). The "average health of all enemies" case is now
  one expression instead of an accumulator loop. Each compiles to a bare `reduce` one-liner over
  `get_tree().get_nodes_in_group(...)` (zero runtime); Sum/Average seed at 0, Min/Max seed at +/-INF so
  an empty group returns the sentinel rather than crashing. A runtime test exercises the reduce math.
- **Custom ACEs guide** ([docs/CUSTOM-ACES-GUIDE.md](docs/CUSTOM-ACES-GUIDE.md)) — a complete how-to
  for authoring your own Actions / Conditions / Expressions / Triggers: the three extension paths
  (auto-ACE provider scripts, custom descriptors via the EventForgeBridge autoload, and built-in
  modules), the codegen-template language (`{param}`, `{uid}`, multi-line, optional-comma, stateful
  conditions), full descriptor + parameter + widget-hint reference tables, the picker / category /
  Simple-Mode rules, and a compile-and-run testing recipe. Linked from the README.
- **JSON is its own module now, with two new ACEs.** The JSON vocabulary (To / From JSON Text, JSON
  Is Valid, Save / Load JSON File) was consolidated out of the Collections module into a dedicated
  **JSON** category, and gained **To JSON Text (pretty)** (indented, human-readable output) and
  **Parse JSON Into Variable** (parse JSON text — a server response, the clipboard — straight into a
  variable). The five moved ACEs keep their ace_ids and codegen templates, so existing sheets are
  unaffected; only the picker category changed (from "Variables: JSON"). Once parsed the value is a
  normal Dictionary / Array, so the Variables: Dictionary / Array ACEs read and edit it.
- **File-management ACEs** — a **Files** vocabulary so save systems, config files and level data never
  force a drop to GDScript: **Read Text File**, **Write Text File**, **Append To File**, **File Size**,
  **File Exists**, plus **Delete / Copy / Move-or-Rename** a file, and a **Files: Directories** set
  (**Make / Remove / Exists**, **List Files / Subdirectories**). Each compiles to the exact native
  FileAccess / DirAccess call: reads use the null-safe static accessors (return "" / [] on error
  instead of crashing) and writes guard the handle *and close it* (so a later op on the same file
  isn't blocked by a still-open write — caught by a runtime round-trip test). Path hints nudge user://
  (res:// is read-only in an exported game). FileExists moved here from the JSON set; JSON file
  save/load stay under Variables: JSON.
- **Remappable keyboard shortcuts** — Tools ▸ Keyboard Shortcuts is now an *editor*, not just a cheat
  sheet: click any of the ~18 authoring shortcuts (Add Event / Condition / Action, Save, Duplicate,
  Copy / Paste, Undo / Redo, …) and press a new combination to rebind it. Clashes are flagged inline
  but allowed (you resolve them); per-action and "Reset all" restore the defaults; the fixed
  structural keys (Tab nesting, Delete, Enter/F2, Escape, Command Palette, zoom) stay read-only for
  reference. Custom bindings save **per-user** to a `user://` file — local to each developer,
  consistent across projects, and never committed to git. (The rebinding backend already existed
  behind ProjectSettings; this adds the UI and moves persistence to per-user storage.)

### Changed
- **Built-in ACE modules are auto-discovered.** Adding a vocabulary module no longer means editing
  `builtin_aces.gd`: any script in `addons/eventforge/registration/modules/` that exposes
  `static func get_descriptors() -> Array[ACEDescriptor]` is now loaded and registered automatically
  (in a stable sorted order, with the generic `helper_aces` module kept last so its catch-all
  templates never shadow a specific ACE in the reverse-lifter). Drop a module file and its ACEs
  appear on the next load. ace_ids and templates remain the compatibility covenant. The **test runner
  auto-discovers tests the same way** (any `tests/*.gd` with `static func run() -> bool`, with the
  shared-state teardown tests forced to run last), so adding a built-in module plus its test is now
  **zero registration edits** — just drop the files.
- **Plainer wording for beginners.** The dock no longer surfaces the insider acronym "ACE" in
  beginner-facing places: the node-drop preview reads "Dropped Node Preview", the row-comment dialog is
  "Row Comment", and the "couldn't edit this row" / "nothing found on this node" messages use plain
  "actions and conditions" language. The advanced custom-ACE provider and export features keep the term
  (it matches the Custom ACEs guide).
- **Removed the redundant "Group" badge on group headers** — a group's accent bar + tinted background
  already read unmistakably as a group, so the leading "Group" text badge was just visual clutter.
  Headers now show only the inline-editable title (and its optional description); selection, the
  group-editor popup, and descendant-block selection are all unchanged.

### Editor UX — plain-language picker, relevance ranking, dialog consistency (UI-audit pass 2)
The user-approved wide clusters from the UI audit:
- **Picker de-jargoned for newcomers** — the picker hints no longer surface the insider acronym
  "ACE"; they read in plain *condition / action / trigger* language (Construct 3 / GDevelop never
  show "ACE" to users). The Sheet / View / Tools menus gained tooltips, the GDScript panel opens with
  a one-line orientation ("the plain GDScript your sheet compiles to — read-only, no runtime"), and
  the behavior-sheet empty state keeps the plain-language search tip it previously dropped.
- **Picker relevance ranking** — type-and-Enter now commits the *best* match instead of "first in the
  grouped tree": matches are scored (exact name > prefix > word-start > substring in name > substring
  elsewhere) so typing "hide" pre-selects **Hide**. The grouped tree is unchanged — only the
  pre-selected target is smarter; a small length penalty favours the shorter, more specific name.
- **Recents persist across editor restarts** — last-used ACEs save per-user and per-project to a
  `user://` file (deliberately **not** project.godot, which would churn on every ACE use), so the
  ★ Recent pane survives a restart the way ⭐ Favorites already do.
- **Variable dialog matches the shared form styling** — it now uses the standard content margin and
  the shared 120px label column (it previously hand-rolled 130px rows and added its form flush).

### Editor UX — keyboard-first dialogs & picker polish (UI-audit pass)
A multi-agent audit of the editor UI found it broadly healthy; the gaps clustered in keyboard/focus
mechanics and the ACE picker. This pass ships the narrow, low-risk wins:
- **Variable dialog is now keyboard-first** — opening it focuses the Name field (and selects it for
  quick overtype when editing), and Enter confirms, matching function_dialog and the ACE picker.
- **ACE picker: Down from the search box enters the results, Escape closes** — typing then pressing
  Down hands focus to the result tree (its native arrow navigation takes over from the pre-selected
  first match), and Escape closes the picker from either the search box or the tree, so the whole
  pick is keyboard-only (the code's prior "arrow/Enter work" claim is now actually true).
- **No-match search now guides instead of going blank** — a search that finds nothing nudges the C3
  vocabulary bridge ("try a plainer word like move, spawn, or hide") rather than showing an empty tree.
- **Node & expression sub-pickers honour Enter** — type-and-Enter commits the first result, matching
  the main picker (those two search boxes previously swallowed Enter).
- **Add Condition / Add Action toolbar buttons now carry editor icons** (MemberConstant / MemberMethod),
  finishing a primary toolbar that previously left two of five buttons text-only.

### Fixed
- **Silent-bug sweep — six defects that shipped invalid or wrong behaviour without ever crashing at
  compile time** (each reproduced by an adversarial sweep, now pinned by `silent_bug_regression_test`):
  - **Awaited multi-statement actions emitted `await var …`.** Marking a multi-line ACE (Spawn Scene
	At…) as awaited prefixed `await` onto the whole joined template, so it landed on the `var`
	declaration line — a parse error that only surfaced at reload. `await` now wraps only the
	trailing statement of a multi-line template.
  - **Distinct trigger sources could collide into one handler.** Two sources that normalised to the
	same token (`A/B` and `A_B` both → `_a_b`) emitted two same-named `func _on_…` handlers (a parse
	error). The token is now injective — an illegal-char path gets a short stable hash suffix — while
	legitimate snake_cased autoload names (`event_bus`) keep their readable handler names unchanged.
  - **Unresolvable conditions silently OPENED the gate.** A condition whose ACE couldn't be resolved
	(addon uninstalled / stale id) was dropped, so the event body ran unconditionally every tick. It
	now fails **closed** (`if false`) with a warning — a vanished gate can never run.
  - **Negating "Every X Seconds…" broke the interval.** Inverting a stateful condition wrapped its
	header in `not (…)`, leaving the timer reset to run in the wrong branch (it fired nearly every
	frame, then went silent). Stateful conditions now refuse the negation, with a warning.
  - **Reverse-lift shadowed specific ACEs with generic catch-alls.** Importing generated GDScript
	matched the generic Core ACEs (SetVar, Call Function…) before specific ones, so `position = …`
	lifted as **Set Variable**, `add_child(…)` as **Call Function**, etc. Reverse entries are now
	tried most-specific-first (by literal-char count), so the round-trip preserves the real ACE id.
	(The byte-roundtrip gate never caught this — the generic re-emits the identical line.)
  - **Charge abilities spent only one stack per regen cycle.** The Simple Abilities pack gated
	activation on the per-stack regen cooldown, so a 3-charge dash used 1 of 3. Activation now gates
	on available stacks alone; the per-stack cooldown stays the regen timer.
  - **Phantom row selection from a span toggle.** Ctrl-toggling an ACE span on then off on a
	previously-unselected row left the row highlighted and drag/delete/edit-eligible. The viewport
	now tracks span-only selection provenance and releases the row when its last span is toggled off.
- **Duplicate `Core::GetFrameCount`** — the dev-helper "Frame Count" reused the same provider+id as
  the canonical Time-category one, so the registry index silently overwrote one entry. Removed the
  duplicate (Frame Count stays under **Time**), and added a suite guard that fails on any repeated
  `provider::ace_id` so this can't regress.
- **Alt+Up / Alt+Down row reordering** — the plain arrow-key selection branches matched first and
  swallowed the modifier, leaving the advertised "move row up/down" shortcut as dead code. The
  selection branches now require Alt to be up, so the move shortcut fires as documented.
- **Param values containing `{…}` were re-substituted** — `_apply_template` replaced placeholders
  iteratively per key, so a param value that itself contained `{anotherparam}` got expanded by the
  later key (e.g. `{a}-{b}` with `a="{b}"` produced `X-X` instead of `{b}-X`). It now runs a single
  left-to-right pass with **opaque** values — your input is emitted verbatim. Behaviour is identical
  on every existing template (golden/parity green, drift = 0); a new test pins the edge cases.
- **Event-trace highlighting was dead without Live Values** — the per-frame trace buffer and its
  debugger send were emitted only inside the `emit_live_values` block, so turning on the event trace
  alone produced no instrumentation. The trace now rides the same throttled `_process` independently
  (a shared "throttle emitted" flag keeps the synthesized and injected `_process` from duplicating);
  trace-only compiles stream `eventsheets:fired_events` correctly. Live-values output is unchanged.
- **Baked `{uid}` locals could collide** — the per-instance token for multi-line ACEs (Spawn Scene,
  Wait, Every-X-Seconds…) was a masked random draw, so two such ACEs in one event body could (very
  rarely) bake the same local and produce invalid GDScript. A central minting helper now tracks
  every token issued this session and re-draws on a clash, guaranteeing distinct locals; the 8-hex
  format is unchanged.
- **Shift+Down from an empty selection** skipped the first row (landed on row 2). It now starts the
  range on the first row, matching Shift+Up.

### Dev helper ACEs — Debug · Groups · Metadata · Nodes (the everyday tools)
- **25 developer-helper ACEs** (`dev_aces`) for the native operations you reach for constantly,
  so common dev/debug chores never force a drop to GDScript. **Debug**: Print, Print Labeled,
  Print Rich, Push Warning, Push Error, Assert, Print Scene Tree, Breakpoint.
  **Groups**: Add/Remove/Is-In Group, Get First / Count In Group, Call Method On Group.
  **Metadata**: Set/Get/Has/Remove Meta. **Nodes**: Get Parent, Get Child / Child Count, Find
  Child, Get Node Or Null, Has Node, Get Scene Owner, Is Ancestor Of — scene-tree navigation that
  was previously uncovered. Each compiles to the exact one-liner you'd hand-write (`print(…)`,
  `add_to_group(…)`, `set_meta(…)`, `get_parent()`); registry + category + codegen unit-tested.
- **12 more math ACEs** under **Math & Random** — Snap To Step, Inverse Lerp, Smoothstep,
  Ping-Pong, Angle Difference, Rotate Toward / Lerp Angle, Deg↔Rad, Positive Modulo, and Is
  Equal / Is Zero (approx) — the movement/animation/AI idioms the existing lerp/clamp/distance set
  was missing.
- **7 Color helper ACEs** under a new **Color** category — Lighten, Darken, Lerp Color, Color With
  Alpha, Color From HSV, Color From Hex, Invert Color — so hit-flashes, fades, and tints stay
  code-free (only the `Set Color Tint` action existed before). The colour params are full
  expressions, so they compose; the generated templates are parse-checked in the suite.
- **7 more helper ACEs** surfaced by a verified gap audit — **Tween Callback** and **Call After
  Delay** (fire a method after N seconds without a Timer node or a blocking `await`), **Set Camera
  Limits** (Camera2D), **Has All Keys** (Dictionary), **Repeat Text** (String), and **Seed Random**
  / **Randomize Seed** (Math & Random). Each compiles to the native one-liner; the multi-line and
  callback templates are parse-checked.
- **4 more from the audit** — **Signal Is Connected** (condition) and **Emit Signal On** (emit a
  signal on any target, reusing the existing optional-args idiom), **Set Text (formatted)** (set any
  node's `text` from a printf template + args in one row — replaces a raw-code block the showcase
  demos used), and **Move By** for 2D (relative translate; 3D already had it). A compile test proves
  Emit Signal On drops the trailing comma when there are no args.
- **Spawn Scene (Full)** — instance a scene with position, rotation, and an optional group tag in
  one row (a per-instance `{uid}` local, like Spawn Scene At). Replaces the raw `load().instantiate()`
  block the showcase demos used. A compile+parse test bakes the `{uid}` the way the dock does.
- **10 more ACEs from a second gap audit** — **Set Anchors Preset** and **Override Theme Color**
  (Control), **File Exists** (save-slot / config guard), **Set Self Tint** (CanvasItem — tint a node
  without affecting its children), **Apply Central Force** + **Apply Torque Impulse** (RigidBody2D),
  **Rotate (3D)** (Node3D), and **Set Speed Scale** for GPU + CPU particles (slow-mo / fast-forward a
  burst). Registry + node-type scoping + method-call templates are all tested.
- **On Body Exited / On Area Exited** triggers (Area2D) — the *entered* triggers existed but not
  *exited* (detecting something leaving a zone). Wired through the resolver and the importer so they
  codegen to a real `body_exited`/`area_exited` connection and round-trip byte-identically.
- **Project utility ACEs** (in the Core module) — the broad non-gameplay glue most games need:
  **Settings** (save/load values to a `ConfigFile` in `user://`), **Window** (set title, window /
  screen size, clipboard get/set), **Debug** (read live `Performance` monitors, static memory),
  **Time** (format seconds as `mm:ss`, system time/date strings), and **Reparent To**. Each compiles
  to the native call; the multi-line and formatting templates are parse-checked.
- **Node manipulation + picking ACEs** (`node_aces`) — build, rearrange, and select scene-tree
  nodes. **Nodes**: Add / Remove / Move Child, Free Node, Duplicate Node, Set / Get Node Name, Node
  Path, Index In Parent, Is Inside Tree, Current Scene Root. **Nodes: Picking**: Get Children, Find
  Children (by name), Nodes In Group, Random Node In Group. Complements the existing Node-navigation
  (Get Parent / Child / Find Child) and Groups sets.

### Simple Abilities behavior pack (the 28th addon)
- A per-instance **ability manager**, authored as an event sheet and compiled to a plain
  `SimpleAbilitiesBehavior` (`extends Node`, zero runtime dependency) — ported from the Simple
  Abilities C3 addon and expanded for Godot. Grant abilities by string id; **cooldowns**; **stack
  charges** that auto-regenerate; **temporary** abilities that auto-expire; per-ability **custom
  data**; and **tags** for bulk enable/remove/reset. 7 triggers (activated / ready / created /
  removed / stack consumed / gained / max reached), 7 conditions, 16 expressions, and 24 actions.
- **Godot-suited extras over the C3 original**: a **Current Ability ID** expression (the C3
  `_currentAbilityID` had no reader — the guide flagged it as missing), an exported global
  **cooldown multiplier** (built-in cooldown reduction the original did by hand), a **Current Ability
  Is** condition for per-id trigger filtering, and a **Ready Abilities** list. The pack rebuilds
  byte-identically (no-drift covenant) and its ACEs are registration-tested.
- **Shift-range row selection** — Shift+click extends a whole-row selection from the anchor to the
  clicked row, and Shift+↑/↓ grows or shrinks that range from the same origin. The anchor is
  preserved across moves (so the range can shrink, not just grow), and it's listed in the Keyboard
  Shortcuts cheat sheet.
- **Simple Mode now filters the ACE picker** — with Simple Mode on (View ▸ Simple Mode), the
  picker hides the advanced "drop to code" + debug rows (Run GDScript, Evaluate GDScript / Expression,
  Breakpoint, Assert, Print Rich) so newcomers see only the friendly, code-free vocabulary. Turning
  Simple Mode off restores everything. Previously Simple Mode only hid advanced *rows*, not picker
  entries.
- **Go back to re-pick an ACE while editing (C3-style)** — the `◀ Back` button in the params dialog
  now appears when editing *any* existing ACE (previously only when adding), and Back re-opens the
  picker **preselected on the current ACE** — so editing an action or expression can go back and
  swap it, exactly like editing a condition already did. Closes the one gap in the existing
  back-navigation flow.

### Editor DX — popup polish, error→row deep-linking, shadow guard, picker, watch + event trace
- **Consistent popups** — a shared `EventSheetPopupUI` helper gives the plugin's dialogs one look:
  aligned **Label  [field]** form rows (fixed label width, fields expand), standard content
  margins, and muted hint labels — matching the Godot 4.7 editor styling instead of each dialog
  inventing its own. The group-editor, breakpoint-condition, function-definition, and
  variable-definition popups adopt it — and the function and variable dialogs each drop a private,
  duplicate form-row helper (`_labeled_row` / `_attr_field_row`) in favour of the shared one. The
  factory helpers are unit-tested.
- **Keyboard Shortcuts cheat sheet** — Tools ▸ **Keyboard Shortcuts** opens an in-editor reference
  (Editing / Search / Debug / View / File & history) so the ~20 shortcuts are discoverable instead
  of learnable only from tooltips. Built from a static, unit-tested catalog via the popup helper.
- **Live event trace** — Tools ▸ **Event Trace** instruments each event (debug compiles only,
  opt-in behind a new `emit_event_trace` flag so normal output is byte-for-byte untouched) to
  stream its UID as it fires over the Live Values channel; the editor **highlights the firing rows
  in real time** (a cyan marker) so you can see which events actually run. Plain core Godot
  (`EngineDebugger`), piggybacking on the Live Values stream. Compiler emission + the viewport
  highlight are unit-tested. With conditional breakpoints, editable Live Values, and the Watch
  panel, this is the step/watch debugging set — automated step-to-next-event (editor-driven
  pause/step) stays out of reach until Godot exposes debugger step control to plugins.
- **Watch panel** — the Live Values window gains a **Watch** box: pin any expression over the
  sheet's variables (e.g. `health <= 0`, `score + lives`) and it's evaluated **editor-side**
  against each streamed values frame via `Expression` and shown live — no compiler instrumentation
  and no new debug protocol (reuses the existing Live Values stream). `evaluate_watch()` is pure +
  unit-tested.
- **Shadowing-variable guard** — naming a variable after a host-class member (e.g. `position` on a
  `Node2D` sheet) breaks the generated script. The variable dialog now **warns live + blocks** it
  (via `EventSheetProjectDoctor.shadowed_member_class`), and the row diagnostics flag any local
  variable already on the sheet that shadows a member.
- **Picker speed — pre-select first match** — the ACE picker now highlights the first result on
  open + as you type, so the description panel populates and arrow/Enter pick it without a first
  click (search auto-focus, "Apply & Add Another", and inline value editing were already in place).
- **Recipes + glossary** — new [`docs/RECIPES.md`](docs/RECIPES.md) (platformer, health, pickups,
  debugging, custom ACEs, common pitfalls) and a one-page [`docs/GLOSSARY.md`](docs/GLOSSARY.md)
  C3 ↔ Godot ↔ EventSheets Rosetta Stone, linked from the README quick start.
- **Error → row deep-linking** — when a ƒx expression or inline GDScript block doesn't compile,
  the editor now flags the **offending row** (a red left-stripe + wash, the message in the row
  tooltip) and jumps to the first one, instead of a status-bar line you have to hunt down. A
  pure, unit-tested `EventSheetDiagnostics.analyze()` lints every block + expression-hinted
  param against the sheet context (reusing the GDScript lint), keyed by the row's instance id so
  the viewport marks it directly — no source-map line mapping needed. Runs on save (the common
  bad-ƒx case the structural compile misses) and on demand via **Tools ▸ Check Sheet for Errors**;
  a bare typo'd identifier also gets a "did you mean …?" suggestion.
- **Group editor popup** — double-click / slow-click / Enter on a group header (and the naming
  step after Add Group) opens a Name + **Description** popup, replacing the inline title edit
  that could never *add* a description (it renders only once non-empty).
- **ACE picker — Create-Node parity** — the Add Action/Condition dialog now mirrors Godot's
  Create New Node: dedicated **⭐ Favorites + ★ Recent** left panes (same persisted data), a ⭐
  star toggle, a real description panel (name · type · category + what it does + codegen), and
  Cancel / Add buttons.

### Advanced Random addon (C3 parity) + ACE sub-categories + read-only .gd preview
- **Advanced Random** autoload pack (27th pack) — a faithful port of Construct 3's Advanced
  Random plugin: seeded numbers / range / int / **dice** / **normal (Gaussian)**,
  **Perlin/Simplex noise** (1D/2D/3D with fractal octaves, via `FastNoiseLite`),
  **permutation tables**, **shuffle bags** (pick without repeats), **weighted** + uniform
  picks, and a **Chance(%)** condition. One shared seed = reproducible runs; 22 ACEs under a
  nested "Advanced Random" picker section.
- **ACE sub-categories** — the picker nests `"Parent: Sub"` categories one level, so related
  ACEs cluster (e.g. the Array/Dictionary/Vector/String helpers under **Variables**).
- **Read-only `.gd` preview** — opening a GDScript file as a sheet defaults to a safe
  read-only preview (gated edits + save, a plain-language banner with Edit Events / Open in
  Script Editor, inline lift-fidelity), so a casual look never overwrites a hand-written script.

### Code-free authoring — stay in the event sheet
Five editor-only conveniences that keep authoring in the sheet instead of dropping to a raw
GDScript block; each reuses the reflection helper or compiles to the same GDScript unchanged.
- **Visual expression builder** — the Insert Expression picker now also lists the sheet host
  class's own reflected members under **This Object — Properties** and **This Object —
  Methods**; picking one inserts `name` (property) or `name()` (method). Editor-only.
- **Reflection-driven method / property pickers** — the Helpers ACEs **Call Method**, **Call
  Method (value)**, **Set Property** and **Get Property** offer the host class's real members
  as an editable suggest-combo (pick a real member, or still type one reflection misses).
  Editor-only; generated code unchanged.
- **Promote block to Function** — a row's More menu gains **Extract GDScript to Function**: it
  gathers that event's inline GDScript (RawCode) actions into a new reusable EventFunction
  (auto-exposed as an ACE under Functions) and replaces them with a call.
- **Visual data editor** — Array / Dictionary variable defaults get an **Edit items…** button
  in the Variable dialog: a one-item-per-line editor instead of typing a literal like
  `[1, 2, 3]` by hand. Round-trips losslessly through the literal.
- **Conditional breakpoints** — a row's More menu gains **Set Breakpoint Condition…**: it
  stores a GDScript boolean expression and the compiler emits `if <cond>: breakpoint` instead
  of a bare breakpoint, so you pause only on the frame that matters (e.g. `health <= 0`)
  rather than every pass; blank clears the guard. Builds on the existing F9 breakpoints, the
  Tools-menu Debug Breakpoints toggle and editable Live Values.

### New ACE vocabulary — UI, particles, tilemaps, animation, shaders, input rebinding, joints, 2D raycast, loops
First-class events for the biggest gaps from the capability audit (roadmap Phases 0/1/2/4/5):
- **UI & menus** (`ui_aces`) — Button **On Pressed** / **On Toggled** triggers (real signal
  connections via new `trigger_resolver` arms), focus navigation (grab / next / previous /
  neighbor), and Range / LineEdit / BaseButton get-set.
- **2D physics queries** — `RayCast2D` + host-agnostic `Node2D` world raycasts
  (`intersect_ray`), mirroring the existing 3D set.
- **Particles** (`particle_aces`) — emit / restart / one-shot / amount + **On Particles
  Finished**, for GPU and CPU particles.
- **AnimationTree** — travel-to-state, set/get tree params, is-in-state, current state.
- **Tilemaps** (`tilemap_aces`) — TileMapLayer set / erase / clear / get-cell + local↔map
  coordinate conversion.
- **Shader materials** — assign / swap / clear a material + read a uniform (completes the
  one-uniform `SetShaderParameter`).
- **Runtime input remapping** — bind / clear / query InputMap action events (settings-menu
  rebinding), built on the captured `event` from On Input.
- **Physics joints** (`physics_aces`) — wire Joint2D/3D bodies, tune pin/spring params,
  break at runtime.
- **Loop control** (`loop_aces`) — Break / Continue / Current Item.
- **Else / Else-If authoring** — a row right-click menu sets the chaining the compiler
  already emitted; **Pick-Filter conditions** now compile (iterator-scoped, AND/OR) instead
  of warning.
- **Collision helpers** (`collision_aces`) — 24 ACEs for body/area physics queries:
  **CharacterBody2D** on-wall / on-ceiling, wall / floor normals, and slide info (Get Slide
  Collision Count, Get Last Slide Collider, Get Last Slide Normal), with **CharacterBody3D**
  carrying the on-wall / on-ceiling / wall / floor-normal subset; **Area2D** overlaps (Overlaps
  Body, Overlaps Area, Has Overlapping Bodies / Areas, Get Overlapping Bodies / Areas), with
  **Area3D** Has / Get Overlapping Bodies; **CollisionObject2D** layer/mask bits (Set Collision
  Layer Bit, Set Collision Mask Bit, Is On Collision Layer); and **CollisionShape2D** Enable /
  Disable Shape (via `set_deferred`).

All compile to plain typed GDScript (parity contract); covered by `phase0_aces_test` and
`new_modules_test`. Bare loop keywords are excluded from the reverse-lifter so generated
`break`/`continue` stay verbatim. (Deferred: a Menu/HUD behavior pack + UI starter demo,
2D point/shape overlap queries, and the Phase-3 dialogue/transition packs.)

## [0.8.0] - 2026-06-20 — "The Team & Scale Update"

### Team & navigation — merge driver, Find References, includes manager + provenance
- **Semantic 3-way git merge driver** (`tools/sheet_merge`) — merges sheets at the row level
  keyed on the now-stable UIDs: two people editing different rows merge cleanly; a genuine
  same-row edit keeps both versions (fenced by ⚠ comment rows) for resolution in the editor,
  instead of an unmergeable `.tres`. Opt-in per clone — see `docs/VERSION-CONTROL.md`.
- **Symbol-aware Find References + Go-to-Definition** — whole-symbol matching (`\bname\b`)
  across params/code/pick/comment/group surfaces, so `speed` finds the variable but never
  `move_speed`; resolves a symbol to its definition; backs a rename **preview** (count what
  it'll touch first).
- **Includes, made usable** — **Edit ▸ Extract Selection to Include…** moves selected events
  into a new library sheet and wires the include (copy-paste → modularization in one step);
  a summarize core powers an include-manager preview (events/functions/variables each
  contributes), with a cycle guard; and a provenance core resolves a sheet's includes into
  their rows for read-only display.
- **AI-assisted event generation** is enabled through the MCP server today (ground via
  `list_aces`/`read_sheet` → the model writes GDScript → `apply_snippet` lifts it losslessly
  into editable events, with `dry_run` preview) — see `docs/MCP-SERVER.md`.
- **In-editor AI generation + a live MCP on/off switch** — **Edit ▸ Generate from Description
  (AI)…** turns plain English into editable event rows in the editor (opt-in via an
  `eventsheets/ai/api_key` setting), and **View ▸ MCP Server (AI tools)** is a checkbox that
  activates/deactivates the MCP server at will: off → connected AI clients see no tools and
  can't read or change your sheets, live, without reconnecting.

### HTN Agent behavior — utility-driven planning (port of the custom C3 DHTN addons)
- A new **HTN Agent** pack: a world-state blackboard + a task network of primitive and
  compound tasks, where each compound's methods carry preconditions, an ordered subtask list
  and a utility score. **Request Plan** decomposes the root task, picking the highest-utility
  *applicable* method at each compound (with backtracking), and yields a plan of primitive
  tasks the sheet runs via **Current Task** + **Mark Complete / Mark Failed**. Triggers: On
  Task Started / On Plan Complete / On Plan Failed. The C3 manager+agent split is collapsed
  into one per-object behavior (the natural event-sheet fit); squad/slot coordination and
  decaying alert stimuli are an honest scope cut. **26 behavior packs total.**

### Theme Editor — "Quick Style" (re-skin without learning every token)
- The visual theme editor gains a **Quick Style** section at the top: pick a **base**,
  **accent** and **text** colour, click **Generate Theme**, and the whole sheet palette is
  regenerated via `EventSheetGodotTheme.apply` (the same derivation the editor-theme adapter
  uses) — plus **Reset To Default**. The full reflective per-token form (every colour/spacing/
  toggle) still sits below for fine-tuning, and now rebuilds to reflect a just-generated palette.

### Platformer-Shooter showcase
- A new playable demo (`demo/showcase/platformer_shooter.tscn`) combining the **Platformer**
  and **Weapon Kit** packs: run + double-jump on a floor, hold to fire (fire-rate + ammo +
  auto-reload), shots destroy targets drifting in. Verified by `showcase_examples_test`.

### Editor UX — naming a new group is immediate
- **Add Group** now drops you straight into renaming the group's title inline (the standard
  "new folder → type its name" flow), instead of leaving a generic "Group" you had to know to
  double-click. The inline title/description edit was already there; this just makes it obvious.

### Version control — byte-stable pack/showcase regeneration (no more diff churn)
- Row UIDs (`event_uid`/`group_uid`) used to be **minted at random** every time a resource
  was created, so rebuilding a single behavior pack rewrote the `.tres` of **every** pack —
  exploding `git diff` with meaningless UID churn, and meaning the "stable" per-row UIDs were
  never actually stable. The pack/showcase builders now stamp **deterministic UIDs** derived
  from each row's structural path, so regenerating unchanged content is **byte-for-byte
  identical** (verified: two consecutive builds produce zero new diff). Each row also keeps a
  genuinely stable identity for diff/blame. Scoped to the builders — hand-authored sheets keep
  the persistent UID assigned when the row was first created.
- (Already in place, for reference: `.gitattributes` enforces LF and wires a readable
  `diff=eventsheet` textconv so `git diff` renders `.tres` sheets as legible event text via
  `tools/sheet_diff.sh` + `EventSheetTextDump`.)

### Behavior packs — C3-addon parity (Platformer juice, Spring colors, new Weapon Kit)
- **Platformer** rebuilt with the feel features from the author's C3 "Physics Platformer":
  **coyote time, jump buffering, variable jump height** (Jump Released), **multi/double jump**
  (max_jumps + Reset Jumps), **wall slide + wall jump**, **acceleration/deceleration** and
  **terminal velocity** — all kinematic on a CharacterBody2D. New conditions (Is Moving /
  Jumping / Falling / Wall Sliding / Can Jump), triggers (On Landed / Double Jumped / Wall
  Jumped) and expressions (Jumps Remaining / Air Time / Facing Direction). The original
  Jump / Set Move Speed / On Jumped ACEs keep their ids (compatibility covenant).
- **Spring** gains the missing pieces of the C3 "Simple Spring": **colour springs**
  (Spring Color / Set Color Value / Color Value — perfect for hit flashes), **spring
  lifecycle** (Pause / Resume / Remove / Reset All), and an **On Spring Started** trigger.
  (Mesh deformation stays an honest skip — that's shader/skeleton territory in Godot.)
- **Weapon Kit** — a new pack ported from the C3 "WeaponKit": ammo + reserve pools,
  fire-rate cooldown, **single / auto / burst** fire modes, **timed + instant reload** with
  auto-reload, and a full HUD surface (Ammo % / Reload Progress / Cooldown Progress,
  Can Fire / Has Ammo / Is Full / Is Reloading, On Fire / Empty / Reload Started / Reload
  Complete). It owns no projectile — Fire manages state and triggers On Fire, so the sheet
  spawns the bullet however it likes. **25 behavior packs total.**

### Richer variable helpers — Array, Dictionary, Vector & String manipulation
- **16 more Array ops** so list work rarely needs a raw block: First/Last item, Index Of,
  Count Of, Reverse, Push To Front, Pop First/Last, Append Array, Slice, Join To Text,
  Array Max/Min, Copy, Resize, Fill.
- **Dictionary**: Copy Dictionary, Has Value (alongside the existing Set/Get/Has Key, Merge,
  Keys/Values, Size).
- **New Vector category**: Make Vector2/3, Length, Normalized, Distance Between, Direction
  To, Angle, Dot Product, Rotated, Lerp, Clamp Length.
- **New String category**: Text Contains / Begins With / Ends With, Split Text, Text→Int,
  Text→Float, Pad Number.
- Every one is a direct GDScript one-liner (parity-safe), so the row doubles as a GDScript
  lesson — a beginner learns `.front()`, `.distance_to()`, `.split()` by using them.

### Behavior-declared autocomplete for string params (Construct-style editable combo)
- A behavior/addon can mark a string parameter for **autocomplete** purely from its own
  code: `## @ace_param_autocomplete(anim "idle", "run", "jump")`. In the params dialog that
  param becomes an **editable combo** — type any value, or open the ▾ list (Down-arrow also
  opens it) and **filter/pick** a suggestion. Unlike `@ace_param_options` (a fixed dropdown),
  free text is always allowed. Toggled entirely by whether the annotation is present.
- Plumbed end-to-end: annotation → semantic analyzer → generator → adapter → `ACEParam`,
  with `make_param(..., autocomplete)` available to builtin/Helper ACEs too.

### Helper ACEs — a structured escape hatch for hard-to-translate GDScript
- A new **Helpers** vocabulary (24 ACEs) for the GDScript a user would otherwise drop to a
  raw block for, so more logic stays as editable rows that still compile to the exact
  one-line GDScript you'd hand-write: **Set/Get Property**, **Call Method** (action +
  value), **Get Node**, **Run GDScript** / **Evaluate GDScript** / **Evaluate Expression**
  (a raw statement/expression as a real ACE), **Inline If (ternary)**, **Toggle Boolean**,
  **Set Local Variable**, **Is Valid** / **Is Null**, **Connect/Disconnect Signal**, and the
  math/string idioms not already covered (**Abs/Min/Max/Round/Sign/Move Toward/Wrap/Remap/
  Format String**).
- The Helper templates are deliberately generic, so they're registered **last** and
  **excluded from the reverse-lifter** — they never shadow a specific ACE on import or
  swallow a line that should stay a verbatim block.
- **Escape-hatch provenance, working together:** raw GDScript blocks now carry an optional
  `note` (a human label, shown on hover) and an importer-set `lift_note` — when a line
  couldn't lift into a structured ACE, hovering the block says *why* ("no matching ACE
  template"), turning an opaque wall of code into an actionable triage list. Both are
  non-emitted (no codegen / round-trip impact) and complement the verbatim-codegen tooltip.

### Health pack
- Renamed **Temporary Health → Health Pools** throughout the Health behavior addon (ACE
  names and the generated API: `add_health_pool`, `on_health_pool_*`, `clear_all_health_pools`).

### New behavior packs + C3-addon parity (24 packs total)
- **Line of Sight 3D** — the 3D twin of the LoS pack (Node3D host, `PhysicsRayQueryParameters3D`
  raycasts, cone-of-view from the host's -Z forward).
- **Health** — a faithful port of the Simple Health C3 addon: max/current HP, damage with a
  resistance/absorption multiplier, **named temporary-health pools** (shields/armour that
  intercept damage in priority order and decay over time), heal/revive/invulnerability, and
  `On Damaged/Death/Healed/Revived/Health Changed` + temp-pool triggers.
- **Virtual Cursor** — a port of the custom C3 Virtual Cursor addon (axis/mouse-driven cursor
  with homing, solids, bounce, constraints) that can **drive the Drag & Drop pack** for
  gamepad/touch dragging.
- **Drag & Drop, rewritten event-driven** — replaces the old mouse-only poller with the C3
  surface (Start Drag / Set Drag Point / Drop, follow-speed lag, direction lock, break-distance
  auto-drop, measured throw velocity, snap/magnet targets) so any input source can drive it.
- All packs stay faithfulness-gated (`audit_addons` drifted=0) and covered by
  `sample_behavior_pack_test` (load-as-behavior, no-drift golden, instantiation).

### 3D, GDScript-escape & install/uninstall improvements
- **3D spatial-query ACEs** — a RayCast3D node set (Is Colliding / Collider / Hit Point /
  Hit Normal / Force Update) plus host-agnostic Node3D **world raycasts** (single-line direct
  space-state queries), closing the biggest functional 3D gap.
- **3D starter templates** — "First-Person Controller (3D)" and "Third-Person Mover (3D)" in
  the New Sheet menu (CharacterBody3D, `Input.get_vector` planar movement + gravity).
- **Raw-block codegen tooltip** — hovering a GDScript block now advertises that it compiles
  verbatim into the generated script (the escape hatch is transparent, not a black box).
- **Clean removal made provable** — [docs/UNINSTALL.md](docs/UNINSTALL.md) (keep/remove table),
  a `clean_removal_test` that parses every generated/pack script with no plugin classes on the
  path and forbids any `EventForge*`/`EventSheet*` reference, and a `plugin_teardown_test`
  asserting every `_enter_tree` `add_*` has a paired `_exit_tree` `remove_*`.

### Showcases refreshed — three playable demos for complex tasks
- Replaced the single version-pinned showcase (`showcase_v070.*`) with **three** playable
  demos in `demo/showcase/`, each authored as event sheets and compiled to plain GDScript:
  - **`showcase_carousel.*` — Carousel of Juice (flagship):** a rainbow ring driven by a
	reused `juice_tile()` function, a runtime-toggleable group, an if/elif/else keypress
	chain, and four behaviors (Spring/Tween/Sine/Flash). Streams to Live Values.
  - **`starfall.*` (+ `star.tscn`) — arcade game:** an enum+match state machine
	(PLAYING/GAME_OVER), a group pick-filter that scores & culls falling stars, an Every-2s
	spawner instancing a sub-scene, and if/elif input branches.
  - **`quest_fsm.*` — software-logic FSM:** a self-driving quest engine using a Dictionary
	inventory + Array quest log, signals (`item_collected`/`quest_advanced`), a reused
	`grant_item()` function, and match dispatch.
- **Stable, un-versioned names** end the per-release churn: only the flagship matches the
  `showcase_*` discovery prefix (so `EventForgePlugin._find_showcase_scene` returns it
  deterministically — no plugin edit), and the two secondaries can never go stale via the
  version-pin smell. Future refreshes regenerate in place via the new single builder,
  `tools/build_examples.gd` (replaces `tools/build_showcase.gd`).
- New `tests/showcase_examples_test.gd` guards all three: each compiles, parses, contains
  its advertised power-feature constructs, and instantiates.

### Adoption: friendlier for newcomers, faster for power users
- **Simple Mode (View menu)** — progressive disclosure for artist-first / first-time users:
  hides the advanced/code-leaning right-click entries (GDScript blocks, sub-conditions, pick
  filters, match, signals/enums) so the everyday authoring verbs stand alone. Persists
  per-project; Expert mode (default) is unchanged.
- **Command Palette (Ctrl+P)** — keyboard-first access to every dock action with a fuzzy
  (prefix › substring › subsequence) filter.
- **Export Generated GDScript… (Sheet menu)** — writes the sheet's standalone, plugin-free
  GDScript to a file you choose: concrete proof you can leave the addon with your code.
- **"Did you mean …?" quick-fix** — an unknown identifier in an expression field that's one
  or two edits from a name the sheet knows offers a one-click swap (alongside the existing
  create-variable fix).
- **Less jargon in the UI** — the C3-internal term "ACE" no longer leaks into the core
  authoring loop ("Add Action / Condition" picker, "Parameters" dialog, "Custom Actions…",
  "Edit Note…", "Expose as a reusable action"); the beginner empty-state drops "host accessor"
  wording.

### Godot 4.7 support
- **Verified on Godot 4.7 stable** — the full headless suite (1869 assertions) and an
  editor smoke run are green on 4.7. Fixed the cases 4.7's stricter `set_script` typing and
  detached-Control theme access exposed (dialog init now also runs from `setup()`, not only
  `_ready()`, so headless paths initialize correctly).
- **Fixed a live-values crash** — the dock called `ensure_window()` but the panel defined
  `_ensurewindow()`; opening Live Values would error. Names now match.

### 4.7 "Modern" theme alignment
- The editor-theme adapter's color math is extracted into a pure `EventSheetGodotTheme.apply()`
  so the sheet's neutral grayscale chrome (4.6+ "Modern" default), light themes, and custom
  accents are now preview-able in the render harness and covered by regression tests.

### Less clutter when getting started
- **Calmer empty sheet** — the dense one-line wall of shortcuts is replaced with a clear
  heading, one call to action, and a single muted tip. It now also shows when the sheet holds
  only the "+ Add event…" footer (previously the footer suppressed it).
- **"Add-Event Rows" toggle** in the View menu hides the trailing "+ Add event…" affordances.
- **"System" object labels are dimmed** — kept (C3 always shows the object) but de-emphasized
  so rows read as the action, not a column of identical "System" labels.
- **"+ Add action" is revealed on hover/selection** instead of repeating under every event
  (events with no actions yet keep it visible for discoverability).

### Context menu, truncated
- **The row right-click menu is rebuilt per click for the row you clicked** — it
  used to be one flat ~30-item list shown for everything (an event right-click
  still offered "Edit Group Description", "Add Enum Below", etc.). Now an event
  shows ~9 items, a group shows group items, a comment shows comment items.
- **The "Add … Below" family folds into an `Insert Below ▸` submenu**, and the
  advanced/rare authoring (sub-condition, pick filter, match, find usages, open
  in split, snippets) folds into a `More ▸` submenu.
- **Bulk-selection items only appear when more than one row is selected** —
  otherwise Copy/Paste/Duplicate/Disable act on the clicked row directly.
- **Insert Snippet moved to the empty-canvas menu** (you're adding to the sheet,
  not acting on a row).

### Godot-native polish
- **The GDScript panel reads like the script editor** — it adopts the editor's
  code font + size, the built-in minimap, current-line highlight and tab
  rendering, so the honest output looks like a Godot script, not a foreign box.
  It re-skins live when you switch editor themes.
- **The default theme is labeled "Match Editor"** — it always derived from your
  editor's base/accent colors; now the picker says so, and it re-derives the
  moment you change your editor theme.
- **Key toolbar buttons carry editor icons** (Save, Run/Play, Add, Script) — the
  same glyphs the rest of the editor uses.
- (Most of the obvious native gaps were already closed: editor-theme colors,
  font + size, row-cell editor icons, Ctrl+wheel zoom, and node drag from the
  Scene dock into expression fields all shipped earlier.)

### Bug-review fixes (silent bugs)
- **Selecting a multi-line block by clicking any line but the first showed no
  highlight** — single-click selects the clicked line's span (usually not the
  block head), but the merged-cell renderer only drew selection at the head. The
  block grouping is now a tested helper (`resolve_block_groups`) and selection
  draws once at the union whichever member line is clicked.
- **A leftover Range/Clamp/Drawer value errored about an invisible field** — after
  switching a variable from numeric to String/bool (which hides those fields), the
  values persisted and the confirm guardrail rejected them with a message about a
  field the user could no longer see. Numeric-only attributes are now inert when
  the type isn't numeric.

### Tier-1 authoring speed: value memory + add-another chaining
- **Apply & Add Another** on the params dialog (append modes) — apply a condition
  or action and the picker reopens for the next one, so building a three-condition
  event no longer means re-summoning the picker each time.
- **Per-ACE value memory** — re-adding an ACE prefills the values you used last
  time (session memory, keyed by ace id) instead of the bare descriptor default.
  The numbers you type repeatedly stop being re-typed.
- (Apply-with-defaults was held back: auto-applying from the picker would hide the
  remembered values and remove the chance to set params — it fights both features
  above.)

### Field-test round 2: the replace flow, fixed for real
- **Shadowed variables are caught at both ends** — naming a sheet variable after
  a host member (`velocity` on a CharacterBody2D sheet…) breaks the generated
  script at load and blinds expression lint. The variable dialog now refuses the
  name with a suggestion, and the Project Doctor flags pre-existing ones at the
  error tier, pointing at Rename Everywhere… (behavior/autoload sheets scope to
  Node — their host members live safely behind `host.`).
- **Preselect now actually shows** — the entry WAS being selected, but inside a
  collapsed picker group, which reads as nothing happening. Preselect expands
  the ancestor chain, runs after the popup settles (carried via the picker
  context instead of racing the open sequence), and scrolls to the entry.
- **OK can never be locked out again** — when a sheet variable shadows a host
  member (e.g. `velocity` on a CharacterBody2D sheet), the lint scratch breaks
  and EVERY expression "failed", so the params dialog just closed and reopened
  without applying. The guardrail now checks the lint baseline first: a broken
  context skips the expression gate instead of locking the user out.

### Field-test round 1: author tooling
- **The Theme Editor is actually editable now** — both panes carry real minimum
  sizes (the token controls used to collapse to an invisible sliver, leaving
  only the preview: "it's just highlighting things"), and the editor-level
  tokens (hover, selection, lanes) join the form, so emphasis strength is
  user-tunable per theme.
- **Sheet functions get a dialog** (Add ▾ → Function…) — the first authoring UI
  for them: parameters expand row by row with auto-unique suggested names,
  function/param names auto-snake_case, duplicates are refused with the reason
  named, and the expose-as-ACE fields stay behind their checkbox. Built for the
  first-time developer: hard to make an invalid function.

### Field-test round 1: dialog UX
- **Double-clicking a condition opens the replace picker, preselected on it** —
  pick another to swap it out, or re-pick the same one to edit its params
  (existing values prefill either way). The "I expect to replace it" reflex.
- **Edit Variable stopped throwing everything at once** — the Inspector
  attributes live behind a disclosure (collapsed for new variables, auto-expanded
  when the variable already uses any); combo options appear only for Strings;
  range/clamp/drawer only for numerics; multiline only for Strings.
- **Sheet enums fill combos in one click** — a "From enum" menu on the combo
  field lists the sheet's enums and fills the options with member names
  (explicit values stripped).
- **Lone Vector2/Vector3 params split into per-axis fields** — positions edit as
  x / y (/ z), each axis still a full GDScript expression, recomposed on apply.

### Field-test round 1: the renderer pass
- **A multi-line GDScript action is ONE cell now** — block lines merge into a
  single vertically-resized code cell instead of stacked per-line cells (the
  per-line spans stay the layout/hit-test truth, so selection, drag and delete
  behave exactly as before).
- **Code cells look like code** — in-flow GDScript gets a cool tint and a left
  code stripe, so "this action is just GDScript" reads at a glance.
- **Comments in the action lane look like action cells** — they carry the same
  cell chrome as their siblings (comment text color kept), merge into one cell,
  and keep growing vertically as lines are added.
- **Hover and selection are easier on the eyes** — whole-row hover (comments
  especially) is a faint tint with no outline; whole-row selection is tempered
  for single-cell rows; span hover is softer and thinner. Selection stays
  unmistakable via the outline and accent bar.

### Field-test round 1: quick fixes
- **Welcome window actually fits now** — rebuilt as a self-sizing dialog (the
  fixed-size window clipped buttons and text at the edges twice); every label
  wraps, the checkbox text is short, and the tooltip carries the detail.
- **Theme switches are no longer undo steps** — undo history is for sheet
  content (ACEs, variables), never presentation. Switching themes still marks
  the sheet dirty (the style is saved with it).
- **The Construct3-stacked theme is removed** — it wasn't a faithful C3 look
  and earned no keep.
- **Toggles explain themselves on hover** — the GDScript toggle, Split/Detach/
  Link, Debug Breakpoints and Live Values all carry tooltips; param dialogs get
  hover descriptions on every label and field.
- **Param dialogs stopped overflowing** — fields fit the dialog width (no more
  horizontal scrollbar under long enum defaults); dropdowns clip long entries.

### Toolbar redesign + welcome fixes
- **The workspace toolbar is grouped and never clips**: Sheet ▾ (file lifecycle +
  identity), Add ▾, Edit ▾, View ▾ (panels, multi-view, zoom, theming) and the
  existing Tools ▾ replace ~28 loose buttons; the C3 reflexes (Add Event /
  Condition / Action), Save, Run Scene, the GDScript toggle, the theme picker and
  Quick add stay one click. The bar is a flow container now — when the panel is
  narrow it wraps to a second row instead of clipping off-screen.
- **Welcome window fixed and reopenable**: content sits in real margins (the
  first cut jammed text against the window edges), the Godot-native checkbox
  reflects the current setting on every open, and **Tools → Welcome…** reopens
  it any time (it previously appeared exactly once per project, with no way to
  see it again).

## [0.7.0] - 2026-06-12 — “The Native Workflow Update”

**EventSheets meets you where you work.** Three arcs in one release: the tedium
killers (rename everywhere, snippets, bulk ops, session restore, asset drops,
one-click attach and run), the Godot-native entry points (right-click a node →
Attach Event Sheet, the Inspector's Edit button, discoverable settings,
rebindable shortcuts, go-to-sheet-row from the script editor), and a GDScript
bridge that explains itself (recursive if/elif/else reverse-lift + the Lift
Report). Showcase: `demo/showcase/showcase_v070.tscn` — press ui_accept /
ui_cancel for the interactive if/elif chain.

### Review + sweep (pre-release)
- A seven-angle code review of the whole range confirmed one bug and four
  cleanups, all fixed: **Run Scene now targets the source `.gd` for
  GDScript-backed sheets** (pairing-rule resolution invented a `_generated.gd`
  for them); the doctor's scene-attachment check reads scene texts once again
  (the shared-lookup refactor had made it O(sheets × scenes)); shortcut
  bindings are parse-memoized per keystroke; the Inspector pairing check is
  memoized by script mtime; the welcome panel discovers the newest showcase
  instead of hardcoding the versioned filename.
- Sweep catches: the export-integrity pass no longer compiles template
  blueprints, and Save/Save As persists the session immediately.

### GDScript coverage: branching lifts, and the boundary explains itself
- **if/elif/else reverse-lift** — opening a `.gd` as a sheet now lifts branching
  into real structure: `if` blocks become conditioned events, adjacent
  `elif`/`else:` become chained else-rows, and *nested* branches become
  sub-events, recursively. Anything unrepresentable falls back to the old
  in-flow GDScript behavior, and the byte-identical recompile still gates every
  lift (lossless, as ever).
- **The Lift Report** (Tools → Lift Report…, plus the open-status summary) —
  after a `.gd` opens, every block explains itself: what lifted into events,
  and why each remaining block stayed code with the closest ACE named ("uses
  await — the Wait action is the structured equivalent"). For C3 users learning
  Godot the boundary becomes the curriculum; for Godot devs it's trust through
  transparency.

### Godot-native workflow (3/3): the first-run hook
- **Welcome panel** on first enable (per project, stored in editor metadata —
  nothing committed, never shows headless): open the playable showcase, jump to
  the workspace starters, and one checkbox — *"I'm Godot-native"* — that opens
  the generated-GDScript panel beside every sheet from then on
  (`eventsheets/editor/open_code_panel_by_default`), so the first thing a
  skeptical Godot dev sees is the honest output.
- Asset Library submission kit deliberately deferred until v1.0.
- Drag-a-sheet-onto-a-node explored and dropped: the Scene dock's drop surface
  isn't reachable from plugins — the Scene dock's "Attach Event Sheet" context
  entry covers the intent.

### Godot-native workflow (2/3): debug, docs and shortcuts like Godot
- **Go to Sheet Row** (script-editor context menu on generated scripts): carries
  the caret line through the compiler's source map into the sheet — the GDScript
  panel opens and the emitting row is selected. Errors and stack traces land on
  rows, not on generated code.
- **Rebindable shortcuts** — every authoring/editing key reads its binding from
  `eventsheets/editor/shortcuts/*` in Project Settings ("Ctrl+D", "Q",
  "Ctrl+Shift+S"); matching is exact on modifiers so chords never shadow plain
  forms. Structural keys (Tab nesting, Delete, Enter/F2, Escape) stay fixed —
  grammar, not preference. (The Editor-Settings shortcut dialog isn't exposed to
  GDScript plugins; this is the rebindable-the-Godot-way alternative.)
- **View in Godot Docs** — native-node ACEs link to the engine's built-in class
  reference from the params dialog: the vocabulary IS Godot, one click away.

### Godot-native workflow (1/3): entry points + discoverable settings
- **Right-click a node → Attach Event Sheet** (Scene dock): creates a sheet whose
  host class matches the node, saves it beside the scene (suffix, never
  overwrite), compiles and attaches the generated script, and lands you in the
  sheet — the "Attach Script" reflex, for sheets.
- **Open as Event Sheet** on FileSystem and script-editor context menus (sheet
  `.tres` files and any `.gd` — GDScript-backed sheets open scripts losslessly);
  sheets now carry a **distinct FileSystem icon** instead of reading as generic
  resources.
- **Inspector "Edit Event Sheet" button** on any node whose attached script is
  sheet-generated (paired via the script's `# Source:` header, pack siblings via
  the pairing rule) — one click from where Godot devs already live.
- **Every `eventsheets/*` setting is now registered in Project Settings** with
  type hints and ranges — discoverable and documented the Godot way, value-neutral
  (defaults match the in-code fallbacks; unchanged values never touch
  project.godot).

### Tedium reduction (Tier 3): the loop closers — attach + run
- **Attach to Selected Node** (Tools) — one click compiles the open behavior sheet
  and parents it under the node selected in the Scene dock (owner set, scene
  marked unsaved). Host-class mismatches warn but attach — the in-scene
  configuration warning already covers it. The save→find scene→add child→attach
  loop the Doctor used to nag about is now the fix-it button.
- **Run Scene** (toolbar) — saves the sheet (compile-on-save keeps the script
  fresh), finds the scene(s) attaching it via the Doctor's reverse lookup, and
  plays: one scene runs immediately, several offer a pick menu, none explains
  what to wire. Sheet → playing game in one click; behaviors are routed to the
  Test Bench.

### Tedium reduction (Tier 3): session restore + asset drops with intent
- **Session restore** — the editor reopens last session's tabs (and re-activates
  the one you were on) on startup; `eventsheets/editor/restore_session` (default
  on) gates it, deleted sheets are skipped silently. Every launch stops starting
  from zero.
- **Asset drops with intent** — drop a `.tscn` from the FileSystem dock onto an
  event row and it becomes a pre-filled **Spawn Scene At** action; drop an
  `.ogg/.wav/.mp3` and it's **Play Sound** — undoable, templates baked exactly
  like a picker apply. The C3 drag-into-layout reflex, grafted onto events
  (empty-space drops explain themselves instead of silently bouncing).

### Tedium reduction (Tier 2): row snippets + bulk selection ops
- **Row snippets** — Save Selection as Snippet… files the selection in
  `res://eventsheet_snippets/` using the SAME text format Copy puts on the
  clipboard (one serializer); Insert Snippet… pastes any library entry through
  the normal paste path (fresh uids, missing variables created). Committed
  files = team-shared patterns, exactly like templates and packs.
- **Bulk selection ops** on the row context menu: Disable/Enable Selection
  (uniform, never a mixed toggle), Duplicate Selection (copies land under their
  sources, uids re-baked), Group Selection into New Group (same-parent
  selections only — cross-depth reparenting is refused, not guessed). Each is
  one undo step.

### Tedium reduction (Tier 2): True Rename + create-variable quick-fix
- **Rename Everywhere…** on variable rows: a word-boundary rename across every
  model surface (params, raw code, pick filters, attributes, comments — prose
  stays honest) in the open sheet *and* every sheet that includes it (saved
  directly, named in the status). Baked codegen templates are never touched —
  a variable named `value` can't rewrite a `{value}` placeholder. Functions
  rename through the same core (`EventSheetRefactor`).
- **Create-variable quick-fix**: an undeclared identifier in an expression field
  grows a one-click **+ var** button — declares it as a float (the C3 "number"
  default) and re-lints, instead of cancel → Add Variable → retype.

## [0.6.2] - 2026-06-12

**The project-usability release** — the whole accepted automation arc: the editor now
keeps generated scripts, project health, documentation and history current *by
itself*. Showcase note: these headliners are workflow tooling, so the playable
`demo/showcase/` from v0.6.0 remains current; this release's living demonstrations
are in the repo itself — the committed [EVENTSHEETS-VOCABULARY.md](EVENTSHEETS-VOCABULARY.md),
the Project Doctor gate in CI, and the sheet-diff textconv driver in CONTRIBUTING.

### Project-usability slice 4: sheet backups + project-local templates
- **Sheet backups** — every save of an existing sheet first rings the file's
  pre-save bytes into `user://eventsheet_backups/` (newest 10 kept;
  `eventsheets/editor/backup_count`, 0 disables). Tools → Sheet Backups… restores
  a backup INTO the editor as an unsaved change — review, then Save to keep; a
  restore never silently rewrites a file. Git-grade safety for projects that
  don't have git discipline yet.
- **Project-local templates** — drop a sheet `.tres` into
  `res://eventsheet_templates/` (or `eventsheets/project/templates_dir`) and it
  joins the New… menu under "Project templates"; Tools → Save as Template writes
  the current sheet in (suffixing, never overwriting). Adopting a template is a
  deep, path-less copy — edits can't leak back into the blueprint. Templates are
  skipped by the Project Doctor and the vocabulary doc (blueprints, not live code).

### Project-usability slice 3: the project vocabulary doc
- **Vocabulary Doc** — one committed markdown reference answering "what can I say
  in this project?": every sheet's class, properties and published
  triggers/conditions/actions/expressions (straight from the model), plus
  hand-written script packs parsed from their `@ace_*` annotations. Deterministic
  by contract (sorted, no timestamps) so it diffs cleanly in PRs — for teammates
  and AI assistants alike. Generate from the dock (Tools → Vocabulary Doc) or
  `tools/vocabulary_doc.gd`; path configurable via
  `eventsheets/project/vocabulary_doc_path`.
- The Project Doctor gains an opt-in staleness note: once a vocabulary doc exists,
  it's flagged (advisory) whenever the project's published surface drifts from it.
- The pack-README section renderer is now shared (`surface_markdown`) between the
  Export Addon README and the vocabulary doc — one rendering, two documents.

### Project-usability slice 2: the Project Doctor
- **Project Doctor** — one audit for the cross-file drift no single check sees,
  identical from the dock (Tools → Project Doctor…), the headless CLI
  (`godot --headless --path . --script tools/project_doctor.gd`, `-- --strict`
  to fail on warnings) and CI (a new gate fails the build on errors).
  - **errors**: a committed generated script no longer matches what its sheet
	compiles to, or a sheet stopped compiling — the pack-golden byte-identity
	contract, generalized to every sheet in the project.
  - **warnings**: never-compiled sheets, autoload sheets that aren't registered
	(or point at the wrong script).
  - **infos**: private variables nothing references, packs no sheet/scene/autoload
	uses, compiled sheets attached to no scene — advisory, never fails CI.
  The doctor never writes inside `res://`; verification recompiles go to a
  `user://` scratch file.
- First catch on this very repo: `demo/showcase/showcase_v060_generated.gd` was a
  committed orphan (the scene attaches `showcase_v060.gd`) — removed, and the doctor
  exposed the silent bug that kept recreating it: default output resolution always
  invented `<name>_generated.gd`, so the export-integrity pass (and compile-on-save)
  duplicated outputs next to builder-shipped pairs like the showcase and every pack.
  `_resolve_output_path` now refreshes the sheet's EXISTING pair — adopting a sibling
  `<name>.gd` only when its `# Source:` header proves the compiler wrote it for that
  sheet, so a hand-written same-name script is never clobbered.

### Project-usability slice 1: compile-on-save + reviewable sheet diffs
- **Compile-on-save** (default on; `eventsheets/editor/compile_on_save` to disable):
  saving a sheet also writes its `<name>_generated.gd`, so F5 can never play-test a
  stale script — the last manual step between editing and playing is gone. A sheet
  that doesn't compile says so at save time instead of at run time.
- **Reviewable sheet diffs**: `EventSheetTextDump` renders any sheet as stable,
  readable rows; `tools/sheet_to_text.gd` + the shipped git `textconv` driver
  (one-line setup in CONTRIBUTING) make `.tres` PRs show events, conditions and
  actions instead of serialized-resource noise — the team-adoption unblock.

### Community-feedback groundwork
- GitHub issue templates: the bug form asks for versions + a minimal sheet or text
  snippet (the two things that make fixes fast); the feature form asks for the game
  situation and the current workaround, and routes C3 requests through the migration
  guide first. README gains a Feedback section.

### Pack builders: one file per pack
- The 1,968-line `build_sample_behaviors.gd` monolith split into
  `tools/pack_builders/` — one builder file per pack (21) plus a shared `_lib.gd`
  scaffold; the runner is a thin ordered orchestrator. **Faithfulness proven by the
  drift audit: all 21 regenerated packs are byte-identical** to the monolith's
  output (`audited=21 drifted=0`).

### Review fixes for the param-picker slice
- A nine-angle code review of the slice confirmed three bugs, all fixed: the scene
  Browse… dialog is now **one cached EditorFileDialog** parented to the persistent
  params dialog (no per-press accumulation, can't be destroyed mid-pick by a form
  rebuild, cancel-safe); **FileSystem drag-and-drop restored** on scene and audio
  path fields (same converter as expression fields, so they can never disagree);
  **Enter applies the dialog** from the new fields (and audio path, which shared the
  gap). Also: the animation walk dedupes in O(n), dropdown entries are
  metadata-tagged instead of index-guessed, and quoting has a single helper.
- Both deferred cleanups are now in too: path-style fields share one scaffold
  (`_build_path_field_base` — container, drag-drop, Enter, registration), and
  exact-match field hints dispatch through a **hint→factory registry** (the next
  hint is one registration line, not another branch).

### C3 param-type parity completed: scene + animation pickers
- **`scene_path` hint** — Browse… opens the editor's file dialog filtered to scenes;
  the chosen path inserts quoted (Spawn Scene At uses it).
- **`animation_reference` hint** — a dropdown of every animation on every
  AnimationPlayer in the edited scene, with free-text fallback for runtime-only names
  (Play Animation uses it). With these, every C3 ACE parameter type is covered
  outright, mapped to a Godot idiom, or an explicit honest skip (layer pickers).
- Hints are dialog-UX only — templates and ace_ids untouched (covenant).

## [0.6.1] - 2026-06-12

**Maintenance release** — no user-facing feature changes; the v0.6.0 showcase remains
current. Structure, hygiene and review actions only:

### Repo re-review + sweep 13
- **Committed scratch removed**: six one-shot patch scripts had slipped into `tools/`
  when their cleanup steps were skipped by mid-script failures — deleted, and
  `tools/_*.py` is gitignored so the class of mistake is closed.
- **Two orphan `.uid` sidecars** removed (their `.gd` files were deleted in earlier
  eras; the sidecars survived).
- Verified clean: no extraction residue (`_dock._dock`, mangled names) in any
  `dock/` helper; the author-loop statics are dock-free; the legacy
  `EventForgeBuiltinACEs._*` delegates have a real consumer (the input/time test)
  and work.

### Dock decomposition (steps 1–4): four subsystems extracted
- The god-object dock (6,455 lines — the repo review's top finding) shed four
  cohesive subsystems into `editor/dock/`: **project find**
  (`project_find.gd`), the **addon-author loop** (`author_loop.gd` — publish
  surface/README statics + preview window/Test Bench), the **Live Values panel**
  (`live_values_panel.gd`) and the **bookmarks panel** (`bookmarks_panel.gd`).
- The dock keeps thin delegates and forwarding properties, so the entire public/test
  surface (1,279 assertions) passed unchanged — pure structure, zero behavior.

### Repo review actions (post-v0.6.0 hygiene)
- **Module split finished**: the remaining Core vocabulary (triggers, InputMap
  conditions, variables, the native-node action set) moved to
  `registration/modules/core_aces.gd`; `builtin_aces.gd` is now a pure ordered
  registry (~50 lines) with the legacy `_make_*` helpers kept as factory delegates
  for external callers.
- **Dead code removed**: three 8-line "Phase 4" importer stubs whose functionality
  shipped inside `ace_lifter.gd` long ago.
- **Era-stale strings**: the compiler's "Phase 1" TODO comments now say what they
  mean (unknown row types are preserved as comments); `plugin.cfg` carries the
  released version in-repo.
- **Eight early-era docs stamped as historical records** (status reports and
  pre-overhaul design briefs that predate the feature waves).

## [0.6.0] - 2026-06-12

### Bug sweep 12 (pre-release)
- **Runtime-group guards on OR-mode events** joined into the OR list — silently
  disabling the gate (`guard or a or b`); guards now AND-wrap the whole condition
  (`guard and (a or b)`), regression-asserted.
- Find in Project now also searches per-ACE `⊳` notes (parity with Replace All).

### Release showcase
- `demo/showcase/showcase_v060.tscn` — the v0.6.0 features in one playable scene: a
  color-tagged **runtime-toggleable group** pulses the host every 2 seconds
  (**Every X Seconds**) through the **Spring** behavior while **Tween** spins it,
  with **Live Values** streaming (watch `pulses` climb — then double-click and
  rewrite it in the running game). Regenerate with `tools/build_showcase.gd`.

### Power-user trio: nested live values, fuzzy picker, keyboard flow
- **Nested Live Values**: dictionaries and arrays expand into read-only subtrees
  (GDevelop's variables-debugger style — `stats → hp / mp`); scalars stay editable.
- **Fuzzy picker matching**: `stt` finds *Set Time Scale* — subsequence matching joins
  after exact + synonym hits, capped at 12 so it never buries real matches.
- **Keyboard flow**: **Enter in the picker search applies the first match**, and Enter
  in any params-dialog field presses OK — `E → type → Enter → type → Enter` authors an
  event without touching the mouse.

### Editable Live Values — C3's debugger, both directions
- The Live Values window is now an **editable tree**: double-click a value while the
  game runs and the change lands in the running game (typed — `3.5`, `true`,
  `Vector2(1, 2)` all parse; plain words stay strings). Streaming frames update rows
  in place so an in-progress edit is never stomped.
- Debug compiles register a tiny `EngineDebugger` edit-back receiver alongside the
  stream (first streaming sheet wins, noted in the window); **normal compiles carry
  neither direction** — the covenant story is unchanged.

### Save System v2 — strategy in the Inspector, extension through signals
- **Every former opinion is now a property**: save directory, file pattern, section,
  **format** (`config` / `json`), and **encryption** (one key field — encrypted
  ConfigFile or encrypted JSON; the suite verifies no plaintext leaks).
- **Variant-typed core**: Save Value / Load Value persist *anything* (Vector2, Color,
  dictionaries…); Save/Load Number/Text remain as thin conveniences (ace_ids are API
  — fully backward-compatible, asserted).
- **Lifecycle broadcasts**: **Save Game** fires *On Before Save* (every sheet writes
  its own state — the pack never needs to know contributors exist), then On Save
  Written; **Load Game** fires *On After Load*. Plus **optional autosave**
  (interval property, 0 = off).
- **Slot metadata for menus**: Slot Exists, List Slots, Slot Modified Time.
- The compiler gained a **Variant-return sentinel** (`TYPE_MAX` → `-> Variant`,
  lifter-aware) to support the Variant-typed core.

### Advanced C3/GDevelop workflows: runtime groups, project-wide find, Save System
- **Runtime-toggleable groups** (C3's *Set Group Active*, opt-in): right-click a group
  → *Runtime Toggleable* — it compiles a `__group_<name>_active` flag guarding every
  contained event (nested groups inherit the innermost guard), with **Set Group
  Active** / **Is Group Active** ACEs. Default stays zero-cost compile-time
  organization.
- **Find in Project** (Tools menu): search every sheet in the project (same surfaces
  Replace All covers), jump to matches, and **Replace in Project** (open sheet goes
  through undo; touched files are named). **Find Usages** on a variable/group row
  pre-fills it.
- **Save System addon (pack 21)**: slot-based persistence as an autoload sheet —
  Save/Load Number/Text, Has Save Key, Delete Slot, On Save Written; human-readable
  ConfigFile underneath; suite round-trips a real save file.
- Release ritual recorded in CONTRIBUTING: every release refreshes the demo showcase
  to exercise its headline features.

### Audits: UI/UX + compiler + sweep 11
- **Sweep 11 (silent bugs)**: the Test Bench wrote (and once committed!) scratch files
  at the repo root — the bench script now rides next to the scene path and the pattern
  is gitignored; the autoload provider scan would have published **every public method
  of every autoload** (including the plugin's own bridge) into every picker — only
  scripts with real `## @ace_` annotations publish now (a doc-comment *mention* of
  @ace_* doesn't count; regression-asserted).
- **UI/UX audit**: the toolbar had grown past 30 buttons — the six workflow tools
  (Debug Breakpoints, Live Values, Bookmarks, Register Autoload, Publish Preview,
  Test Bench) now live in one **Tools** menu.
- **Compiler audit**: pipeline order re-verified end-to-end; the `on_changed` typo
  warning no longer silently skips sheets with zero functions (the case most likely
  to be a mistake).
- **README milestones truncated** to one row per release (the table had drifted to 26
  rows with shipped entries stranded below "planned").

### The addon-author loop: Publish Preview, auto-READMEs, Test Bench
- **Publish Preview** (toolbar): a live window showing exactly what this sheet
  publishes to other sheets' pickers — triggers, conditions, actions, expressions and
  exported properties — straight from the model, so renaming a function updates the
  surface instantly (no compile-and-reopen loop).
- **Export Addon… now writes a README.md** into the pack: tags, host class, properties
  (with their attribute tooltips/defaults), the full ACE surface, and composition
  dependencies — shared packs are documented by default.
- **Test Bench** (toolbar): one click compiles the behavior, builds a host +
  behavior scene, and runs it — verify a behavior without hand-building a scene
  (pairs with Live Values).

### Event-bus triggers — autoload signals fire events in ANY sheet
- The Event Bus pattern is complete: signals on a **registered autoload** publish as
  project-wide triggers ("On Game Paused — EventBus"), and consumer sheets compile a
  direct by-name connection (`EventBus.game_paused.connect(_on_event_bus_game_paused)`)
  — the non-self connection codegen the pairing spec has anticipated since the
  behaviors era. No node paths, works from every scene.
- Registered autoloads with annotated scripts now **join the provider scan
  automatically** (zero-config, like `eventsheet_addons/`): their triggers/ACEs appear
  in every sheet's picker under the singleton's name.

### Autoload (Singleton) sheets — a new pillar
- **New sheet type: Autoload (Singleton)** — Game State, Event Bus, Save System and
  friends, built as event sheets. Set the type + a global name in the Sheet Type
  dialog, then **Register Autoload** (toolbar) compiles next to the sheet and writes
  the ProjectSettings entry in one click — guarded against missing names, unsaved
  sheets, broken compiles, and **name collisions** (it never overwrites a different
  autoload).
- **Project-wide ACEs**: exposed functions on an autoload sheet publish ACEs that call
  **through the singleton name** (`GameState.add_score(10)`) — no node paths, callable
  from every sheet and from hand-written GDScript alike.
- **Three singleton starters** in the New… menu: **Game State** (score/lives with
  Inspector attributes + On Score Changed), **Event Bus** (project-wide signals,
  documented usage), **Save System** (ConfigFile save/load with a typed return).
- Covered by `tests/singleton_sheets_test.gd` (11 assertions).

### Group color tags + picker favorites (the suggestion list, completed)
- **Group colors** (C3 parity): right-click a group → *Group Color…* — the picked
  color tints the group's accent bar and background (clear returns to theme tokens;
  mirrors per-comment colors). Organize big sheets by color.
- **⭐ Favorites in the picker**: right-click any entry to pin it; favorites sit above
  ★ Recent and **persist in ProjectSettings** — per-project and PR-shareable, so team
  vocabularies travel with the repo (same philosophy as the composition policy).

### Single-param inline editing + picker info pane
- **C3's fastest gesture**: double-click a highlighted *value* inside any condition or
  action and edit just that parameter in a one-field popup — no full dialog. Values map
  back to their params verbatim (equal values disambiguate by occurrence order);
  commits are undoable.
- **Picker info pane**: selecting an entry shows its description **and the exact
  GDScript it generates** at the bottom of the picker — C3's info bar doubled as the
  teach-Godot surface.

### Spring + Tween behavior packs (packs 19 & 20) + sweep 10
- **SpringBehavior** — a cleaned-up Godot port of the author's C3 *simple_spring*
  addon: **named numeric springs** (per-spring stiffness/damping/precision), Spring
  To / Between, impulses, Stop/Configure, **On Spring Reached**, Is Springing, and
  value/velocity/progress expressions — plus host helpers (Spring Host X/Y/Angle/
  **Scale** for one-action squash & stretch). Framerate-independent semi-implicit
  integration (damping = fraction of velocity lost per second); the suite *simulates*
  a spring and asserts convergence + the reached-trigger. Mesh deformation from the
  C3 original is an honest skip (shader territory).
- **TweenBehavior** — Godot Tweens the C3-behavior way: transition + easing as
  Inspector **combos** (all 12 Godot transitions), default duration with range
  attributes, one-action Tween Position/Scale/Rotation/Alpha/any-property,
  Stop Tweens, Is Tweening and **On Tween Finished**.
- Both packs showcase Inspector attributes shipping inside packs (ranges + tooltips
  on their exports). Pack counts refreshed everywhere (20).
- **Sweep 10**: live-value chips positioned with the control width *inside the zoomed
  transform* — drifted at zoom ≠ 100% (now uses the logical canvas width); the early
  architecture-slices tracker is stamped as a historical record (its "scaffolded"
  claims all shipped).

### UX polish: C3 reflexes + the general polish set
- **E / C / A single keys** add an event / condition / action on the selection — the
  C3 keyboard reflexes, joining Q (comment) and G (group).
- **★ Recent in the picker**: your last-used ACEs pin to the top while not searching
  (newest first, deduped, capped at 8).
- **Onboarding watermark**: empty sheets now teach the keys and the C3-phrase search.
- **Inline live values (rung 3)**: streamed frames draw `= value` chips next to
  variable rows in every pane — the window remains for the full list.
- **Drag-handle grip dots** on the hovered row's edge — reordering is discoverable.
- **Bookmarks panel**: a toolbar window listing every Ctrl+B row; activate to jump.
- **Find → Split**: the find bar's "Open in Split" jumps the split pane to the current
  match.
- `AGENTS.md` refreshed (architecture map, standing contracts, docs map, suites/tools).
- Covered by `tests/ux_polish_test.gd` (6 assertions).

### Full audit: features, themes, addons, docs (sweep 9)
- **Themes**: 4 of 10 presets (Construct3-stacked, high-contrast, soft-light, designer
  template) predated the column-header tokens and rendered headers with generic
  defaults — backfilled from each preset's own palette
  (`tools/backfill_theme_headers.gd` kept as a maintenance tool). All 10 presets now
  cover every token.
- **Addons**: all 18 behavior packs audited (`tools/audit_addons.gd`) — every pack's
  `.tres` recompiles **byte-identical** to its shipped `.gd` (zero drift since the
  last regeneration) and every shipped script loads cleanly.
- **Silent bugs (sweep 9)**: pasting the same event twice into one trigger duplicated
  the baked `__spawn_`/`__sfx_` locals in a single function body (same bug class as
  the Every-X-Seconds accumulator, action-template side) — uids now re-bake on
  duplicate/paste; Replace All now also covers per-ACE `⊳` notes.
- **Stale docs corrected**: Live Values and the MCP server are no longer "planned/
  candidate" in `EDITOR-UI-SPEC` (both shipped); bookmarks marked shipped in the
  parity matrix; `GDSCRIPT-PAIRING-SPEC`'s "Planned" section renamed
  **Planned → Delivered** (behavior packs, the C3 coverage program and ACE-level
  lifting all shipped); export-integrity hook noted as shipped.

### Theme Editor preview brought current
- The live preview's sample sheet now exercises the newest renderer vocabulary:
  **BBCode comments**, **per-ACE `⊳` notes**, **Repeat/pick loop rows**, and a
  **disabled row** (strikethrough) — so restyling shows everything the renderer can
  draw. (The token form was already current by construction — it reflects over the
  style resource — and `EVENTSHEET_THEME_TOKEN_SPEC.md` needed no changes: the newer
  vocabulary reuses existing span tokens.)

### Inspector attributes Tier 3 (custom drawers) + bug sweep 8
- **Custom drawers** (the Odin-cosmetics tier): pick *Progress bar* in the Variable
  dialog and the Inspector renders the value as a bar (range-aware). Mechanism: the
  compiler bakes an `eventsheet:progress_bar:<min>:<max>` marker into
  `@export_custom`, and one `EditorInspectorPlugin` recognizes it — **without the
  plugin the property degrades to a plain field**, so generated scripts stay plain
  GDScript (the parity covenant, by construction). The marker format is the extension
  point for future drawers (swatch rows, dials).
- **The Inspector-attributes spec is now fully delivered** (Tiers 1–3 + tool buttons).
- **Sweep 8**: the duplicate-hook guard now also covers `_process`/`_ready`/
  `_physics_process` — a raw GDScript block colliding with a generated trigger
  function (or the Live Values standalone `_process`) warns by name instead of
  silently emitting a script that won't compile; combos report ignored drawers too.
- `tests/inspector_attributes_test.gd` grew to 30 assertions.

### Live Values (debugging rung 2) + bug sweep 7
- **Live Values**: toggle it on the toolbar, recompile, run — the sheet's variables
  stream to an editor window every 0.25s while the debugger is attached (C3's debugger
  panel, the Godot way). Debug compiles inject a throttled `EngineDebugger` send into
  `_process` (merging with an existing process trigger, or emitting a standalone one);
  **normal compiles never carry the stream** — same covenant story as breakpoints,
  plain core-Godot API only. Sheets without variables warn instead of emitting.
- New editor pieces: `EventSheetLiveValuesDebugger` (EditorDebuggerPlugin capturing
  `eventsheets:live_values`) registered by the plugin entry point and wired to the
  workspace editor's Live Values window.
- **Sweep 7 (silent bugs)**: duplicating/pasting an **Every X Seconds** condition no
  longer shares one accumulator between the copies (the member uid re-bakes on
  fresh-uid assignment — C3 copies are independent timers); combo variables now
  **warn** when Tier-2 attributes are ignored instead of dropping them silently;
  Show If / Lock Unless targeting an unknown variable warns at compile (typo guard).
- Covered by `tests/live_values_test.gd` (11 assertions).

### Tool buttons + MCP policy awareness
- **Tool buttons** (Odin's `[Button]`): give a sheet function a *Tool Button Label*
  and the Inspector shows a clickable button running it
  (`@export_tool_button("Label") var _btn_x: Callable = x`, Godot 4.4+). Non-@tool
  sheets get a compile warning pointing at the Sheet Type toggle — the button needs a
  tool sheet to act in-editor.
- **MCP is now policy-bound**: with `include_sources = tagged:approved`, untagged
  addon ACEs disappear from `list_aces` (Core builtins always list) — an AI assistant
  told "only approved addons" is enforced, not advised. This completes the composition
  spec's four enforcement points.
- Suite: inspector test 24 assertions; composition test 25.

### Inspector attributes Tier 2 + doc refresh + sweep 6
- **Tier 2 attributes** on exported globals: **Clamp to range** (`clampi`/`clampf`
  setters), **On Changed** (setter calls a sheet function — typos warn at compile),
  **Show If** / **Lock Unless** (one aggregated, canonical `_validate_property()` —
  hidden or read-only until a bool variable is true), and static **Read-only**
  (`@export_custom` usage flags). All from the Variable dialog, validated before
  commit; behavior packs inherit everything.
- **Sweep 6**: a GDScript block that also defines `_validate_property`/
  `_get_configuration_warnings` now warns (duplicate functions don't compile — the
  cause is named instead of a mystery parse error); GDScript-backed sheets now say
  they ignore Includes/Uses/Requires instead of silently dropping them.
- **Doc refresh**: implementation-status sections added to the two reference design
  studies (`docs/spec/`) and the three `docs/elements/` notes now explain their
  relationship to the live virtualized renderer (preview templates vs theme tokens).
- `tests/inspector_attributes_test.gd` grew to 20 assertions.

### Addon composition Lane B.2 — sibling-behavior requirements
- Behavior packs can declare **Requires (sibling behaviors)** in the Sheet Type
  dialog: the compiler emits a canonical `_get_configuration_warnings()` that checks
  the parent's children by class (native or script class), so Godot shows its **⚠
  badge** the moment a dependency is missing — the Unity *RequireComponent* idiom,
  warning-only by design (no silent auto-mutation of the user's scene).
- Invalid class names warn and skip; sheets without requirements emit nothing.
- `tests/addon_composition_test.gd` grew to 22 assertions. The composition arc
  (Lane A + policy + B.1 uses-instances + B.2 requirements) is complete.

### Addon composition Lane B (v1) + maintainability & sweep 5
- **Uses (addon classes)** in the Sheet Type dialog: declared classes emit owned helper
  instances (`var __uses_screen_shake := ScreenShake.new()`) so ƒx/blocks call shared
  provider addons without duplication — has-a composition, still plain GDScript.
  Invalid class names warn and skip. (Node-behavior auto-attach is the planned B.2.)
- **Maintainability**: `sheet_compiler.gd` now opens with a full pipeline overview
  (the 7 emission phases, both compile paths, and the four standing contracts) — the
  file is the plugin's heart and now reads like it.
- **Sweep 5**: unsaved sheets no longer produce a blank name in the composition-off
  policy error; match-row branches joined the node-reference audit; the variable
  dialog's attribute prefill (incl. the range field) is now regression-covered.
- `tests/addon_composition_test.gd` grew to 17 assertions; inspector test to 11.

### Addon composition Lane A — meta-packs / jam kits, with project policy
- **Addons can now include other addons** (compile-time bake): the Sheet Type dialog
  gains an *Includes (addon sheets)* field, and the merged result compiles to one
  standalone class — a *Jam Kit* meta-pack is one include away, with zero runtime
  coupling (the compatibility covenant untouched).
- **Project policy knobs** under `eventsheets/addons/*` in ProjectSettings (versioned,
  PR-reviewable, CI-readable): `composition_mode`, `max_include_depth` (the
  anti-addon-hell rail), `collision_policy` (warn/error/silent), `include_sources`
  (`tagged:approved` turns the tag system into enforcement), `deprecated_tag_blocks`,
  `export_bundling`. **Defaults are permissive — jams never meet the policy system.**
- **The invariant** (test-pinned): policy never changes emitted bytes — it only gates.
- **Export Addon… bundles included sheets** so packs travel complete.
- Covered by `tests/addon_composition_test.gd` (12 assertions). Spec status updated.

### Spec: addon composition (addon includes addon)
- `docs/ADDON-COMPOSITION-SPEC.md` — analysis + design for addons building on other
  addons: compile-time inclusion (meta-packs / jam kits — first), has-a runtime
  dependencies with auto-attach (second), inheritance honestly skipped; pros/cons by
  project size and the anti-"addon hell" rationale (bake-at-compile, shallow chains,
  collision warnings, export bundling).

### Inspector attributes, Tier 1 (Unity/Odin-style, the Godot way)
- Exported globals can now carry **Tooltip** (emitted as the `##` doc comment Godot
  shows natively on hover), **Group** (`@export_group` Inspector sections), **Range**
  (`@export_range` sliders on int/float) and **Multiline** (`@export_multiline` on
  String) — set from the Variable dialog's new *Inspector* section, validated before
  commit (range demands `min, max, step` on a numeric type).
- Canonical emission order (tooltip → group → annotated export line); combos keep
  their `@export_enum` prefix alongside attributes; behavior-pack properties get all
  of this for free. External `.gd` files with attribute lines round-trip
  byte-identically (raw fallback — the lossless rule).
- Spec: `docs/INSPECTOR-ATTRIBUTES-SPEC.md` (Tier 1 now shipped; Tiers 2–3 still
  planned). Covered by `tests/inspector_attributes_test.gd` (9 assertions).

### Builtin vocabularies fully modularized
- The legacy groups in `builtin_aces.gd` moved into per-module files under
  `registration/modules/` — **System** (time/display/text/comparisons/stateful/spawn/
  shader/date/platform), **Device input**, **3D vocabulary**, **Collections** — joining
  Audio on the documented module contract (`ace_factory.gd`). Each C3-equivalent
  "addon" is now one readable, standalone-shippable file.
- Shared helpers (`COMPARISON_OPERATORS`, InputMap option builders) moved to the
  factory as the canonical home; the registry concatenates modules **in their original
  order**, and every ace_id/template is byte-identical (compatibility covenant — the
  full suite, golden round-trips and lift tests gate the move).

## [0.5.0] - 2026-06-12

### Node picker, large-project edition + bug sweep 4
- The node picker grows the full large-project toolkit: **filter chips**
  (2D/3D/UI/Audio/Physics), **`group:`** and **`script:`** queries, **`scene:`
  cross-scene search** (scans `.tscn` node headers project-wide), **pinned recents**,
  and a **"Used in sheet" audit** listing every `$Ref` the sheet makes — missing nodes
  flag red (broken-reference detection after scene restructures).
- Sweep 4 fixes: the audio preview now stops when the params dialog closes (it kept
  playing); keypad keys capture as their real constants (`KEY_KP_ADD`, not `KEY_KPADD`).
- README refreshed around the core philosophy (speed-to-game, newcomer-to-expert,
  jam-ready, scales with the project).
- Covered by `tests/node_picker_test.gd` (10 assertions).

### Spec: Inspector attributes (Unity/Odin-style, the Godot way)
- `docs/INSPECTOR-ATTRIBUTES-SPEC.md` — design for Range/Tooltip/Group/Multiline/
  Show-If/On-Changed/Tool-Button/Read-only attributes on sheet variables, tiered by
  mechanism (pure annotations → generated setters/`_validate_property` →
  EditorInspectorPlugin drawers), with data model, dialog UX, canonical emission
  shapes and lifting rules. Later phase; parity + lossless contracts preserved.

### Searchable scene-node picker
- Expression params gain a **🔍 Pick Node** browser next to ƒx: a filterable tree of the
  edited scene — the filter matches **name, class or path** (type `Area2D` to see every
  area, `UI/` to scope to a branch), double-click inserts the `$Path` reference
  (identifier-safe quoting) at the caret. Built for large scenes where drag-drop means
  scrolling hundreds of nodes.

### Audio module (the C3 Audio addon, the Godot way) + the new module structure
- **Play Sound / Play Sound At (2D)** — C3's fire-and-forget Play: a throwaway
  AudioStreamPlayer(2D) that frees itself when finished (multi-line `{uid}` template;
  zero bookkeeping, zero plugin runtime), with bus + volume params.
- **Player-scoped group** (attach to an AudioStreamPlayer — music & controlled playback):
  Play (from seconds), Play Sound File, Stop, Seek, Set Volume, Set Playback Rate,
  Is Playing, Playback Position.
- **Godot extras C3 fakes with tags**: Set Bus Volume / Mute Bus / Bus Volume
  (AudioServer) — master/music/SFX sliders in one action.
- **▶ Sound preview in the params dialog**: audio params show a preview button — hear
  the file before applying (■ stops).
- **Maintainability**: vocabularies now live in per-module files
  (`registration/modules/audio_aces.gd` first) built through a shared
  `EventForgeACEFactory`, with a documented module contract — each C3-equivalent
  "addon" is one readable file that can ship standalone or be curated into packs.
  Existing groups migrate over time; ace_ids/templates frozen (compatibility covenant).
- Covered by `tests/audio_aces_test.gd` (9 assertions).

### Device input vocabulary (C3 Keyboard / Mouse / Gamepad / Touch)
- **Keyboard**: Key Is Down (`is_physical_key_pressed`), On Key Pressed/Released
  (event-scoped, for On Input events) — and key params use **C3's press-a-key
  workflow**: click the field, press the key, the `KEY_*` constant is captured
  (with a fallback dropdown for undetectable keys).
- **Mouse**: button-down condition, world/screen position expressions, Set Mouse Mode
  (visible/hidden/captured/confined — the Godot-contextual extra).
- **Gamepad**: button-down (12-button dropdown), axis expression (sticks + triggers),
  is-connected, and **Vibrate Gamepad** (weak/strong motors).
- **Touch**: touchscreen-available, On Touch / Touch Released (event-scoped), touch
  position. Plus C3 search synonyms for all four devices.
- **Dialog-width fix**: long helper labels in the variable/enum/signal/match/pick dialogs
  now autowrap, so dialogs open compact instead of stretching to the longest sentence.
- Covered by `tests/device_input_test.gd` (13 assertions).

### Per-ACE comments + starter templates
- **ACE comments** (C3's per-condition/action notes): right-click any condition or
  action → "Edit ACE Comment…" — the note renders dimmed after the ACE text (`⊳ why
  this exists`), undoable, persisted on the resource.
- **New… templates**: a toolbar menu with **Blank**, **Platformer Starter** (move +
  gravity + grounded jump) and **Top-down Starter** (8-way `get_vector` movement) —
  adopted unsaved, compile-verified, the C3 new-project feel.

### Debug & polish: breakpoint UX, Find & Replace, shader/date/platform vocabulary
- **Breakpoints are fully wired**: F9 persists onto the event resource, and the new
  **Debug BP** toolbar toggle turns debug compiles on per sheet (`breakpoint`
  statements pause the real Godot debugger; normal compiles untouched).
- **Find & Replace**: the find bar gains a replace field + **Replace All** — one
  undoable substitution across comments, GDScript blocks, string params, pick-filter
  expressions, group names/descriptions and match branches, with a count.
- **Set Shader Parameter** (C3 effects → Godot materials, StringName idiom),
  **Date & Time** (datetime string, unix time) and **Platform** (OS Name,
  Has Feature with the mobile/web/pc dropdown) vocabularies.
- **Families** mapped honestly in the migration guide (node groups + behavior packs);
  the **live-values overlay** is spec'd as the next debugging rung (EngineDebugger
  channel design, deferred to its own slice).
- Covered by `tests/debug_polish_test.gd` (9 assertions).

### Language gaps closed: C3 Loops, Pick Instances, returns, group locals, real breakpoints
- **The full C3 Loops set** in the pick-filter dialog (with a C3-named preset menu):
  **For** (indexed), **For Each**, **For Each (ordered)**, **Repeat**, **While** — Repeat
  compiles to `for i in range(n)`, While to a real `while`, all reusing the picking
  pipeline (predicates and first-N still apply).
- **The C3 Pick Instances set** as presets: Pick all, **by comparison/evaluate**
  (predicate), **by highest/lowest value** (ordered + first-1), **nth**, **random**
  (`[….pick_random()]`), **last created**, **overlapping point** — powered by **ordered
  picking finally compiling** (`order_by` sorts a copy via `sort_custom`; descending
  flips the comparator). *Pick nearest* is `order by distance, first 1`.
- **Function return types**: `EventFunction.return_type` (Variant.Type) emits
  `-> int:` etc., **Return Value / Return** actions author it, and typed functions
  **verify-lift round-trip**. Non-void functions are usable in ƒx expressions.
- **Group-local variables** (C3): variables attached to a group compile as class members
  under a `# <Group> — group locals` header.
- **Real breakpoints**: gutter-flagged events (persisted as `EventRow.debug_break`) emit
  a `breakpoint` statement when the sheet's debug-compile toggle is on — pausing the
  actual Godot debugger. Normal compiles are untouched.
- Covered by `tests/language_gaps_test.gd` (16 assertions).

### Bug sweep 3 (stateful-condition hardening)
- **GDScript-backed sheets compiled broken scripts when a stateful condition was added**
  (Every X Seconds referenced a member the external path never declared) — members now
  insert before the first function, skipping any already present verbatim so untouched
  round-trips stay byte-identical.
- Disabled stateful conditions no longer leave orphan member declarations behind.
- Stateful conditions in OR-mode events now **warn** (the accumulator rebases whenever
  ANY condition passes — usually not what you meant; use a dedicated event).
- All three regression-asserted in `tests/stateful_aces_test.gd` (now 15 assertions).

### C3 System coverage, batch 2: stateful conditions + multi-statement actions
- **Every X Seconds** — C3's most-used System condition, done the parity-safe way:
  each applied instance bakes a **private class member** (fresh uid), a prelude line
  accumulates `delta` before the `if`, and an on-true line rebases the accumulator
  inside it. Plain members, plain statements, zero indirection; per-frame triggers only
  (documented). Stateful events never chain as Else/Else-If (warned + emitted
  standalone).
- The machinery is generic: descriptors can declare `member_template` /
  `codegen_prelude` / `codegen_on_true` — future latches and cooldowns ride the same
  rails, including from addons.
- **Multi-statement action templates**: baked templates may span lines (each emitted at
  body indent, `{uid}` locals baked per instance) — enabling **Spawn Scene At**
  (instance + position + add_child in one action, C3's create-object-at-position).
- Covered by `tests/stateful_aces_test.gd` (11 assertions).

### C3 System coverage, batch 1: time, display, text, comparisons
- **Time group**: Set Time Scale (`Engine.time_scale` — C3's slow-motion staple) + Time
  Scale / Game Time / FPS / Frame Count expressions.
- **Display group**: Set Fullscreen Mode (window-mode dropdown), Set Window Size, Window
  Width/Height expressions.
- **Text group** (the C3 System string functions, as direct String methods): Token At /
  Token Count (`get_slice`), Find, Left/Right/Mid, Upper/Lowercase, Length, Replace,
  Trim, **Zero Pad** (`"%0*d" %`).
- **Generic comparisons**: Compare Values (`{a} {op} {b}` with the operator dropdown) and
  Is Between Values — plus C3 search synonyms for all of it.
- Covered by `tests/system_aces_test.gd` (9 assertions).

### BBCode-lite comments
- Comments now style with a small BBCode subset: **[b]bold[/b]**, *[i]italic[/i]*, and
  **[color=#ff7777]…[/color]** (hex or named colors), rendered natively on the
  virtualized canvas with nesting support.
- **No data loss, ever**: the raw text (tags included) remains the editing and
  serialization truth — inline editing shows the tags, styling only shapes the pixels.
  Unknown tags strip gracefully (inner text survives), unclosed tags degrade sanely, and
  plain bracket text like `array[0]` is never mistaken for markup.
- Covered by `tests/bbcode_comments_test.gd` (13 assertions).

### 3D behavior packs (starter quartet)
- **Sine 3D** (oscillate along x/y/z or around Y, full wave set), **Orbit 3D** (XZ-plane
  circling), **Bullet 3D** (launch along the host's forward with gravity + distance
  tracking, relaunchable), and **Move To 3D** (Vector3 waypoint queue + On Arrived) —
  eighteen packs bundled total, all sheet-built and covered by the pack test's
  no-drift/load/publish assertions.

## [0.4.0] - 2026-06-10

The polish-and-reach release: the starter **3D vocabulary**, a **five-fix silent-bug
sweep** (plus a second sweep fixing stale addon tags on plain sheets), **find that
reaches folded groups**, **addon tags** (searchable, MCP-filterable, with documented use
cases), the **showcase demo README**, an up-to-date Theme Editor preview, and
**CONTRIBUTING.md** for open-source readiness. Details below (newest first).

### Sweep 2 (pre-tag)
- Plain sheets now clear `addon_tags` on type switch (no stale never-emitted tags), and
  the analyzer's directive handling is regression-tested against the generated-pack
  layout (`@ace_tags` above `@icon(...)` above `class_name`).

### Open-source readiness: CONTRIBUTING.md
- A contributor guide distilling the project's institutional knowledge: the verification
  loop (with its known quirks), the house rules (compatibility covenant, performance
  parity, lossless rule, zero-config addons, hidden optimization, guardrails), canonical
  emission + golden-regeneration workflow, how-to-add recipes (ACEs, addons, packs,
  themes), and the GDScript gotcha list that has bitten before.

### Find reaches folded groups + addon tags
- **Ctrl+F now searches the FULL tree**: matches inside collapsed groups are found, and
  stepping onto one **unfolds the path to it** and lands on the row (the sweep's known
  limitation, fixed properly via tree search + reveal).
- **Addon tags**: tag any addon with a class-level `@ace_tags(movement, retro, jam)`
  annotation — or the **Tags field** in the Sheet Type dialog for sheet-built addons
  (emitted into the generated script, zero-config as always). Tags are **searchable in
  the picker**, ride along on every ACE the provider publishes, and are **exposed and
  filterable over MCP** (`list_aces` now matches tags and reports them).
- Covered by `tests/addon_tags_test.gd` (7 assertions) + the folded-find assertion in
  `tests/godot_feel_test.gd`.

### Silent-bug sweep (five fixes)
- **Linked panes stole the active view**: mirroring a selection re-emitted
  `selection_changed` in the mirrored panes, silently rerouting Ctrl+/, copy/paste and
  every selection-driven op to the wrong pane. Mirrored selections are now inert
  (regression-asserted).
- **Find-step used stale indices**: matches captured at typing time pointed at the wrong
  rows after any edit — F3 now recomputes matches on every step.
- **Closing one secondary pane reset the active view** even when the *other* pane was
  active; the reset is now conditional.
- **"Open in Split" silently did nothing** for rows inside folded groups in the split
  pane — it now unfolds and retries.
- **MCP server served stale sheets**: the long-lived server read `.tres` files through
  Godot's resource cache; reads now bypass the cache (`CACHE_MODE_IGNORE`).
- Known limitation surfaced by the sweep (deferred, by design of the flat-row model):
  Ctrl+F doesn't match rows hidden inside folded groups.

### Starter 3D vocabulary
- **14 native 3D ACEs** under their node-type groups: **Node3D** (Set Position/Rotation/
  Scale, Move By, Look At, position expression), **CharacterBody3D** (Is On Floor,
  Move And Slide, Set/Get Velocity), **RigidBody3D** (Apply Central Impulse), and
  **Camera3D** (Make Current, Set FOV) — plus the **Input Vector** expression
  (`Input.get_vector`, StringName idiom, InputMap dropdowns) for 2D and 3D movement
  alike.
- Tween, visibility/tint, math & random, scene flow, and audio were already
  dimension-agnostic; signal/collision triggers work on 3D nodes unchanged. The README's
  "2D-first" con is softened accordingly.
- Covered by `tests/native_3d_aces_test.gd` (7 assertions).

## [0.3.0] - 2026-06-10

The multi-view release: the same sheet in split panes, detached OS windows, and linked
follow-selection views — all full editors over one source of truth — plus experimental
tool sheets (`@tool` + EditorScript with the On Editor Run trigger: editor tooling
authored as events). Details below (newest first).

### Tool sheets (Phase D — EXPERIMENTAL): build editor tooling from events
- **`@tool` sheets**: a Sheet Type checkbox emits `@tool` ahead of
  `class_name`/`extends`, so sheet-built nodes and behaviors run inside the editor.
- **Editor Tool preset** (Sheet Type → "Editor Tool"): an `EditorScript` host paired
  with the new **On Editor Run** trigger — your events run from **File > Run**
  (Ctrl+Shift+X). Batch renames, scene generation, project chores: event-sheet style.
- Full citizen: generated tools **verify-lift back** (On Editor Run round-trips
  byte-identically) and `tool_mode` recovers when re-opening a generated `.gd`.
- Explicitly **experimental and editor-version-coupled** (editor APIs are Godot's most
  volatile surface — runtime ACEs stay on stable APIs only, per the covenant).
- Covered by `tests/tool_sheets_test.gd` (10 assertions).

### Multi-view complete: detached windows + linked panes (P2/P3)
- **Detach** (toolbar): a floating OS window hosting another full-editing pane over the
  same sheet — drag it to a second monitor while debugging. Same shared per-sheet state
  (breakpoints/bookmarks/disabled) and the same refresh bus as the split pane.
- **Link** (toolbar): follow-selection across panes — selecting a row in any pane
  scrolls/selects it in the others. Keep the split zoomed out as an overview and click
  rows to focus them in your detail pane (recursion-guarded; unlink any time).
- With Split (P1) + full dual-pane editing (P1.5), the multi-view arc from the spec is
  **complete**. Covered by the extended `tests/multi_view_test.gd` (21 assertions).

### Multi-view phase 1.5: both panes are full editors
- The split pane graduated from read-only companion to a **full editor**: double-click
  edits, dialogs, drag/drop, context menus, find — everything works in either pane (the
  dock's handlers are payload-driven, so one handler set serves both).
- **Active-view routing**: selection-driven toolbar ops (copy/paste, Ctrl+/, Alt+arrows,
  Add Condition/Action, quick-add anchors) follow the **last-focused pane**; closing the
  split falls back to the primary.
- **"Open in Split"** (row context menu): pins the row in the other pane — opening the
  split automatically if needed — the "keep this visible while I work over there" move.
- Covered by the extended `tests/multi_view_test.gd` (14 assertions).

### Multi-view phase 1: split view (same sheet, two panes)
- A **Split** toolbar toggle opens a second pane over the SAME sheet (VSCode's
  one-file-two-editors gesture) — read a handler while editing the function it calls,
  keep a group pinned while debugging another.
- **Per-sheet state is shared by reference** (`EventSheetViewState`): breakpoints,
  bookmarks, and the disabled overlay agree across panes instantly. Scroll, zoom,
  selection, and folds stay per-pane.
- Every edit refreshes both panes (the refresh bus); the companion pane is
  read/navigate-only in phase 1 (inline editing stays in the primary — full
  active-view editing is the spec'd phase 1.5). Closing the split restores the layout.
- Covered by `tests/multi_view_test.gd` (10 assertions).

## [0.2.0] - 2026-06-10

Thirty-five features since 0.1.0 — the C3 coverage program (38 native-node ACEs, all 14
behavior packs with C3-capability parity), first-class rich variables (enums, collections,
combos, the Dictionary/Array/JSON ACE set), signals/match/input vocabulary, the importer's
function verify-lift, gutter bookmarks, sheet includes, find-in-sheet + script-editor
shortcuts, editor-theme inheritance + six iconic theme presets, color params with sheet
swatches, the MCP server, Export Addon Pack, drag-from-docks, scene-aware completion, and
the group-compile fix. Highlights below (newest first).

### Export Addon Pack, Godot-native affordances, README overhaul
- **Export Addon… (toolbar)**: one click turns the current behavior sheet into a
  published pack folder (`eventsheet_addons/<class_snake>/` — editable `.tres` +
  compiled `.gd`, no-drift rule honored, FileSystem rescanned) with guardrails for
  non-behavior sheets and invalid class names. The addon-builder loop is now fully
  in-editor: author behavior → annotate → Export → ACEs published project-wide.
- **Drag from the docks into ƒx fields**: drop a FileSystem file → its quoted `res://`
  path; drop a Scene-dock node → a `$Path` reference (relative to the edited scene,
  quoted automatically when the name needs it).
- **Scene-tree-aware completion**: `$Child.` now completes against the OPEN scene's
  actual nodes — script methods, signals, and class members — and direct children appear
  as `$Name` candidates in flat completion.
- **README rewritten** as a proper front door: honest pros & cons, current status,
  milestones table, and a quick start — kept current with every major update from now on.
- Covered by `tests/phase_c_affordances_test.gd` (12 assertions).

### Behavior packs aligned with their C3 capabilities
- **Sine**: seven movement types (horizontal, vertical, forwards-backwards, size, angle,
  opacity, value-only) and **five wave shapes** (sine, triangle, sawtooth,
  reverse-sawtooth, square) — both Inspector combos — plus phase, Update Initial State
  (C3's `updateInitialState`), and a readable `wave_value`.
- **Orbit**: elliptical orbits (primary/secondary radii), offset angle, match-rotation,
  total-rotation tracking. **Bullet**: distance-travelled tracking + enable toggle.
- **Move To**: a real **waypoint queue** (Move To Position replaces, Add Waypoint
  appends; On Arrived fires at the final stop) + rotate-toward-motion.
- **Follow**: a **delayed mode replaying the target's position history** (C3's
  delay-based Follow) alongside the smooth-chase mode. **Drag & Drop**: axis locking
  (both/horizontal/vertical). **Car**: `drift_recover` (low = drifty) and
  turn-while-stopped.
- **Tile Movement**: **Simulate Step** (C3 simulate control), a default-controls toggle,
  and grid-space helpers (`to_grid`/`from_grid`). **Line of Sight**: a **cone of view**
  and a second condition, *Has LOS Between* arbitrary positions.
- All regenerated through the pack pipeline (no-drift goldens updated) and guarded by
  `tests/pack_parity_test.gd` (17 functional assertions on real instantiated behaviors).

### Combo properties + color params (C3's Combo/Color, the Godot way)
- **Combo variables**: String variables can declare allowed values ("Options" in the
  variable dialog, comma-separated). Exported combos compile to **`@export_enum`** — a
  real Inspector dropdown — and **verify-lift back** with their options intact
  (byte-identical round-trips). Guardrail: the default must be one of the options.
  The Sine pack's `movement` showcases it (horizontal/vertical/angle dropdown).
- **`@ace_param_options(param a, b, c)`** annotation: addon ACE params render as
  dropdowns in the params dialog — the C3 Combo for addon authors, zero config.
- **Sheet-enum-driven params**: the `enum:State` param hint offers the enum's members
  (`State.IDLE`, …) as a dropdown — combos backed by real enums.
- **Color params**: the `color` hint (or a Color-typed param) renders a **color picker**
  in the params dialog, values round-trip as canonical `Color(r, g, b, a)` literals, and
  **conditions/actions with a color param draw a small swatch** next to their text in
  the sheet (C3-style color preview). Set Color Tint now uses it.
- Covered by `tests/combo_color_test.gd` (15 assertions).

### Nine new behavior packs (C3 coverage, Phase B — all fourteen C3-style behaviors bundled)
- **Sine** (oscillate position/angle), **Orbit** (circle a point), **Bullet** (angle-of-
  motion movement with acceleration/gravity), **Move To** (glide to a point + On
  Arrived), **Follow** (smoothly trail a node path), **Drag & Drop** (mouse grab within
  a radius + On Drag Start / On Dropped), **Car** (accelerate/brake/steer, speed-scaled
  steering, `move_and_slide`), **Tile Movement** (grid stepping + On Step Finished), and
  **Line of Sight** (a raycast-backed *Has Line Of Sight To* condition).
- All built as event sheets through the established pack pipeline (`.tres` source +
  generated `.gd`, zero-config ACE publishing, behaviors attach as child nodes,
  properties in the Inspector) and guarded by the pack test's no-drift goldens,
  class-load, and publish assertions — the compatibility covenant in action.

### Native-node ACE providers (C3 coverage, Phase A)
- **38 new builtin ACEs wrapping native Godot features** — lane 1 of the C3 coverage
  program (the engine maintains the implementation; we maintain vocabulary):
  - **Tween Property** (Godot `create_tween` with transition/ease dropdowns — the C3
	Tween behavior's job, natively),
  - **Scene** group (Go To Scene, Restart Scene, Quit, Set Paused, Spawn Scene
	Instance, Is Paused — C3's layout actions),
  - **AudioStreamPlayer**, **AnimatedSprite2D**, **Camera2D**, **Label**,
	**NavigationAgent2D** (C3 Pathfinding), and **CanvasItem** visibility/tint groups,
  - **Math & Random** expressions: Random, Random Integer, **Choose** (C3's `choose()`
	as `[…].pick_random()`), Clamp, Lerp, Distance To, Angle Toward.
- **C3 search synonyms** for the new vocabulary ("go to layout" → scene, "choose",
  "play sound", "set text", "fade"/"animate" → tween, "find path"…), and the migration
  guide gains the full **three-lane behavior/plugin mapping table**.
- Covered by `tests/native_node_aces_test.gd` (18 assertions).

### Iconic theme presets (Dracula and friends)
- Six new bundled themes built from the palettes people already live in: **Dracula,
  Nord, Gruvbox Dark, Monokai, Solarized Light, and Catppuccin Mocha** — every token
  mapped deliberately (conditions take the palette's cool accent, actions the
  warm/green, groups the signature color, comments the comment color; lanes get a
  whisper of their accent over the background).
- Generated by `tools/build_theme_presets.gd` (rerun after token additions); the
  existing presets (high-contrast, soft-light, C3-stacked, designer template) remain.
  All presets are load-verified by the style test.

### Signal rows + match rows (GDScript language parity)
- **Signals are first-class rows** (the enum-row treatment): add via the row menu
  ("Add Signal Below") or double-click to edit — name plus typed params one-per-line
  (`damage: int`). They compile canonically (after enums, before variables),
  **verify-lift** back from generated code (non-canonical formats stay blocks,
  byte-identical round-trips guarded), travel in **snippets**, feed the **On Signal /
  Emit Signal pickers**, lint (`hit.emit(3)` validates), and **validate custom-signal
  trigger connections** at compile time. Names/params pass the identifier guardrails.
- **Match rows** (C3's switch, GDScript's `match`): a structured action-lane row with an
  ƒx subject expression and branch text in real GDScript match-body syntax — enum members
  complete in patterns. Renders as indented action cells; double-click opens the match
  dialog, whose commit guardrail **lint-checks the whole construct** (broken matches
  never commit). Compiles in-flow inside the event body, source-mapped.
- Covered by `tests/signal_match_rows_test.gd` (16 assertions).

### Hidden codegen optimization + signal autocomplete (C3 object-signal parity)
- **ACEs now emit expert idioms behind the scenes** (new spec rule, "Hidden
  optimization"): hot-path builtin templates use `&"name"` **StringName literals**
  (input polling, `is_in_group`, `play`), skipping the per-call String→StringName hash
  in per-frame code. The picker shows the same friendly labels; user ƒx expressions and
  GDScript blocks are **never** rewritten; existing sheets keep their baked templates.
  EmitSignal's template also got fixed to emit a valid `emit_signal(&"name")`.
- **Signal autocomplete everywhere** (like C3's object signals/tags):
  - Dot-completion now offers **signals** alongside methods/properties — typed
	variables (`zone.` → `body_entered`), behavior `host.`, and `$GlobalClass.`
	including script-declared signals (`$PlatformerMovement.` → `jumped`).
  - Signal params (On Signal, Emit Signal) render as a **dropdown** of the host
	class's signals plus signals declared in the sheet's GDScript blocks — pick,
	don't type. Custom values persist as the first option.
- Covered by `tests/signal_autocomplete_test.gd` (8 assertions) + updated input tests.

### Godot-feel batch: find-in-sheet, script-editor shortcuts, editor-theme inheritance
- **Ctrl+F find bar**: script-editor-style find-in-sheet (matches visible row text AND
  GDScript block code, case-insensitive); Enter/F3 next, Shift+F3 previous, Esc closes,
  with an "n of m" counter and wrap-around.
- **Script-editor shortcut conventions**: **F9** toggles breakpoints (Ctrl+B stays as an
  alias), **Ctrl+/** toggles the selected rows' enabled state — the "comment out" of
  event sheets — and **Alt+Up/Down** moves the selected row (reusing the drag machinery,
  fully undoable).
- **The sheet inherits your editor theme**: when no explicit theme is chosen, default
  visual tokens derive from the editor's base + accent colors (dark/light/custom-accent
  editors all match out of the box), and the initial zoom honors the editor display
  scale on hi-DPI. Theme presets and per-sheet themes still override.
- Covered by `tests/godot_feel_test.gd` (14 assertions).

### Input vocabulary + Wait/Await (Godot-familiarity batch 1)
- **Input ACE group** — the most-used trigger family finally has first-class vocabulary:
  Is Action Pressed / On Action Just Pressed / On Action Just Released conditions,
  Action Strength + Input Axis expressions, and **On Input / On Unhandled Input**
  lifecycle triggers (`_input(event)` / `_unhandled_input(event)`) that compile AND
  verify-lift back from generated code.
- **Action params are dropdowns read from the project's InputMap** (custom actions
  first, then the `ui_*` defaults) — pick real actions instead of typing strings.
- **Wait / Wait For Signal** actions (C3's System → Wait): compile to
  `await get_tree().create_timer(s).timeout` / `await <signal>` — handlers are implicit
  coroutines in GDScript, so awaiting mid-event is safe and idiomatic.
- Covered by `tests/input_time_aces_test.gd` (14 assertions).

### MCP server — AI tooling (the backlog's final item)
- **A pure-GDScript Model Context Protocol server** ships in the addon
  (`addons/eventsheet/mcp/`): the Godot binary itself is the server process — no
  Python/Node dependencies. Setup guide: `docs/MCP-SERVER.md`.
- Six tools for AI assistants: `list_sheets`, `read_sheet` (structured JSON of rows/
  variables/enums/functions; also opens any `.gd` as a sheet), `list_aces` (the full
  vocabulary incl. zero-config addons), `compile_sheet` (**dry-run by default**),
  `lint_block` (compile-check against sheet context), and `apply_snippet` (append rows
  from snippet text or plain GDScript via the lossless paste pipeline — the only
  mutating tool, `.tres`-only, append-only).
- Transport-free protocol core (`EventSheetMCPServer.handle_message`) covered by
  `tests/mcp_server_test.gd` (21 assertions); the stdio loop is a thin newline-delimited
  JSON-RPC wrapper (launch with `--headless --quiet`).

### Curated collection ACE set (rich-variables phase 3 of 3 — the 1.0 arc is complete)
- **27 ready-made Dictionary / Array / JSON ops** as builtin Core descriptors, grouped in
  the picker as **Variables: Dictionary** (Set/Delete Key, Clear, Merge, Has Key,
  Is Empty, Get-with-default, Size, Keys, Values), **Variables: Array** (Append, Insert
  At, Remove At, Erase, Clear, Sort, Shuffle, Contains, Is Empty, Value At, Size, Pick
  Random), and **Variables: JSON** (To/From JSON Text, JSON Is Valid, Save/Load JSON
  File — `user://` paths survive exports).
- Every op compiles to a **single direct GDScript line** (`inventory["sword"] = 1`,
  `scores.append(10)`, `JSON.parse_string(...)`) — parity-safe, reverse-lift-eligible,
  and the templates double as GDScript teachers. The long tail stays one ƒx away.
- **Type-aware variable dropdowns**: `variable_reference:Array` / `:Dictionary` hints
  filter the dropdown to matching variables (typed containers match their base;
  Variant/untyped always qualify) — with a clear "No Array variables — add one first"
  block when none exist.
- **C3 migration guide** gains a data-plugins table (Dictionary/Array/JSON addons → the
  Variables groups; XML → intentionally unsupported, use JSON).
- Covered by `tests/collection_aces_test.gd` (15 assertions). With enums (phase 1) and
  collection variables (phase 2), **the first-class rich-variables feature is complete**.

### Collection variables (rich-variables phase 2 of 3 — 1.0 scope)
- **Array and Dictionary variables are first-class**, including Godot 4 typed containers
  (`Array[int]`, `Dictionary[String, int]`, …) offered in the variable dialog's type list.
- **Defaults edit as GDScript literals** (`{"sword": 1}`, `[1, 2, 3]`) with a live ✓/✗
  hint while typing, and a commit guardrail: invalid literals never save (wrong container
  kind, garbage, or **element-type mismatches** against the declared `Array[T]` /
  `Dictionary[K, V]` — with int→float allowed, as in GDScript).
- **Canonical emission**: containers compile through a recursive, escape-correct,
  deterministic literal formatter (`{"k": 1, "nested": {"ids": [1, 2.5]}}`); editing an
  existing collection variable shows that same canonical literal.
- **Verify-lift round-trips**: canonical collection declarations in generated `.gd` files
  re-open as editable variable rows with their values intact; non-canonical formatting
  stays a verbatim block — byte-identical round-trips guarded.
- Covered by `tests/collection_variables_test.gd` (17 assertions).

### C3-familiarity batch: group descriptions, slow-click editing, rename refactoring, commit guardrails
- **Group events now actually compile** — the batch's tests exposed that events inside
  groups were silently dropped with a TODO comment (a long-standing compiler hole).
  Groups flatten inline at emission, with C3 semantics: **disabling a group drops all of
  its children from the compiled output**; group comments compile as comment lines.
- **Group descriptions** (C3-style): a muted, inline-editable second line on the group
  header (`EventGroup.description` — also via the row menu "Edit Group Description…");
  travels in snippets. Group titles were already double-click renameable.
- **Slow double-click editing** (Explorer-style): click an already-selected editable
  cell again after the double-click window (450–1600 ms) to start editing — comments,
  group names/descriptions, variable rows; multiline comments route to their dialog.
- **Variable rename refactoring**: renaming a variable rewrites every reference across
  the sheet — GDScript blocks (class-level, in-flow, function bodies), ƒx/string params,
  pick-filter expressions, and **baked codegen templates** (placeholders like `{amount}`
  are never touched). Whole-word matching; the status bar reports how many references
  updated. A rename can no longer silently break compiled code.
- **Commit-time guardrails** ("you can't enter broken stuff"): variable and enum names
  auto-correct where fixable (`my var` → `my_var`, digit-led names prefixed) and are
  **blocked with a clear message** when not (GDScript keywords); broken GDScript blocks
  never commit (the dialog reopens with your text intact); the params dialog refuses to
  apply while any ƒx expression fails its compile-check.
- Covered by `tests/ux_guardrails_test.gd` (29 assertions).

### First-class enums (rich-variables phase 1 of 3 — 1.0 scope)
- **Enums are sheet rows**: add via the row menu ("Add Enum Below") or double-click to
  edit (name + members, optional explicit values like `HURT = 4`). They compile to
  canonical class enums **before variables**, so `var state: State` works — and exported
  enum-typed variables get Godot's **Inspector dropdown for free**.
- Full citizen everywhere: rendered as keyword-badged rows; **verify-lifted** back from
  generated code (non-canonical/multi-line enums stay verbatim blocks; byte-identical
  round-trip guarded); travel in **snippets**; expressions referencing them **lint**
  correctly; `State.` **dot-completes the members** in ƒx fields and GDScript blocks;
  source-mapped for provenance.
- Scope decisions recorded: rich variables (collections UX + curated Dictionary/Array/
  JSON ACE set) are **required for 1.0**; **XML support is dropped** — JSON is the
  interchange format. Covered by `tests/enum_row_test.gd` (16 assertions).

### Inspector polish: widget_hint editors + per-row "Selected ACE" properties
- **widget_hint-specific inspector editors**: exposed ACE params with `widget_hint`
  (or an `@ace_param_hint`) now render custom controls in Godot's Inspector — `slider`/
  `range` → HSlider (bounds from `range: "min,max,step"` metadata), `multiline` →
  TextEdit, `expression` → the ƒx-style line editor. Unknown hints keep Godot's default
  widgets. (Construction is editor-only; class mapping is headless-tested.)
- **Per-row "Selected ACE" section**: selecting a condition/trigger/action in the sheet
  surfaces *that row's* parameters as live Inspector properties. Edits route through the
  dock's undoable write path (the exposed node never mutates sheet resources itself) and
  refresh the viewport immediately; deselecting clears the section. This closes the last
  two open items from the editor param-exposure spec.
- Covered by `tests/inspector_polish_test.gd` (15 assertions).

### Gutter bookmarks + compile-time sheet includes
- **Bookmarks**: Ctrl+M toggles a session bookmark on the selected row (gold pennant in
  the gutter beside the breakpoint dot); **F4 / Shift+F4** cycle forward/backward through
  bookmarked rows with wrap-around. Session-scoped navigation aids (not persisted),
  synced through the central row-state pass so they survive refreshes.
- **Sheet includes are real** (the `includes` field finally has semantics, C3-style):
  list other sheets' `res://….tres` paths in the Inspector and their **variables,
  class-level blocks, events, and functions merge into this sheet's generated script** at
  compile time. The root sheet wins name collisions (warned), cycles and missing files
  are skipped with warnings, and included rows never enter the editing model — a shared
  "library sheet" pattern. Ignored for GDScript-backed sheets. (Field retyped
  `Array[NodePath]` → `Array[String]`; it was never used or serialized before.)
- Covered by `tests/bookmarks_includes_test.gd` (18 assertions).

### Importer completed: function verify-lift + comment preservation (two-pass safe)
- **Sheet functions lift back** when opening generated `.gd` files: their `@ace_*`
  annotation blocks reverse into `expose_as_ace`/name/category/description, parameters
  parse with types, and bodies use the event grammar with **lenient ifs** — unmatched
  control flow becomes in-flow GDScript inside the event instead of failing the file
  (trigger bodies got the same upgrade). Codegen templates and icons are regenerated
  rather than stored (behavior identity — `class_name`, host, behavior mode — is now
  recovered from the prelude so `$Class.fn()` templates verify).
- **Trailing top-level comments lift** into comment rows; the external compile path now
  emits top-level comments (it silently dropped them before — found by the byte-verify).
- **Two-pass safety**: when the full lift can't verify byte-identically, the event-only
  lift retries, so these upgrades can never regress previously-lifting files. Also fixed
  a latent revert leak (the shallow backup left a boundary row's stripped newline behind
  after a failed verify, corrupting round-trips).
- End-to-end fixture: the shipped **PlatformerMovement pack re-opens fully** — events,
  exposed functions, annotations, comments — with only the `_enter_tree` host-binding
  scaffold staying a verbatim block (external emission keeps the prelude untouched by
  design). Covered by `tests/function_lift_test.gd` (13 assertions).

### Intellisense upgrades: dot-context completion, signature hints, quick-add bar
- **Dot-context completion** in GDScript blocks and ƒx fields: typing `host.` offers the
  host class's members, a typed sheet variable offers *its* class's members, and
  `$TimerBehavior.` offers that behavior's script methods + base-class members (resolved
  via ClassDB + the global class list). Unresolvable tokens offer nothing rather than
  guessing; non-dot contexts keep the flat sheet/host candidates. One shared choke point:
  `EventSheetGDScriptLint.completion_for_context`.
- **Signature hints**: while typing inside a call, the editor shows the signature —
  sheet functions from their declared params, host methods from ClassDB
  (`signature_hint`, displayed via CodeEdit's code-hint popup in both editors).
- **Quick-add bar** (toolbar): C3's "type to insert" — `every tick` creates the On
  Process event (synonym phrasing honored), `heal 5` applies the Heal action with
  `amount = 5` (trailing words fill parameters positionally). Ties prefer the most
  specific name ("process" picks On Process, not On Physics Process); unknown queries
  report and decline. Covered by `tests/intellisense_test.gd` (16 assertions).

### Three more behavior packs: Timer, Flash, State Machine
- **TimerBehavior** (host: any Node): Start Timer / Stop Timer ACEs, exported
  `duration`/`repeating`, and the **On Timer** trigger (repeats when repeating).
- **FlashBehavior** (host: CanvasItem): Flash / Stop Flash ACEs blink the host's
  visibility at an exported `interval` for a duration, restore it, and fire
  **On Flash Finished** — the C3 Flash behavior.
- **StateMachineBehavior** (host: any Node): Set State action, **On State Changed**
  trigger `(previous, next)`, and an **Is In State condition** authored as an annotated
  class-level GDScript block — the reference example for mixing expose-as-ACE functions
  with hand-annotated block ACEs (including a custom codegen template) in one behavior.
- All authored as behavior sheets via `tools/build_sample_behaviors.gd` (editable `.tres`
  beside compiled `.gd`), no-drift goldens + publish assertions extended in
  `tests/sample_behavior_pack_test.gd`.

### Signal-handler lifting (round-trip for signal triggers)
- **Sheets that use signal triggers now lift back into events.** Previously any generated
  file with a signal trigger failed the all-or-nothing lift entirely (handlers aren't
  lifecycle functions). Now `_ready`'s leading connect lines are parsed into a handler →
  {signal, source node} map: Core signals reverse to their trigger ids (`_on_body_entered`
  → On Body Entered), custom ones become `signal:<name>` triggers with the handler's
  argument signature as `trigger_args` and the connect's `get_node("…")` path as
  `trigger_source_path`. Connect lines themselves are skipped (emission regenerates
  them), so a connects-only `_ready` produces no phantom OnReady event.
- Handlers with no connect entry (scene-wired) keep the whole file as verbatim blocks —
  the lossless byte-identical contract is unchanged and still gates every lift. This also
  upgrades paste-GDScript-as-events for pasted scripts containing signal handlers.
  Covered by `tests/signal_lift_test.gd` (13 assertions).

### Post-1.0 polish: pick filters compile, fx autocomplete, external-sheet watcher
- **Pick filters compile** — the last event-flow TODO is gone. C3's "for each" picking,
  the Godot way: each filter wraps the event body in a direct `for` loop over a node
  group / the children / any GDScript iterable, with an optional iterator-scoped `where`
  predicate and a first-N cap; conditions gate the loop and multiple filters nest. Pick
  rows render as "For each item in group \"enemies\"…" lines in the condition lane,
  author via the row context menu ("Add Pick Filter (For Each)…") and edit/delete via
  double-click. order_by and condition-based filtering warn honestly (predicate is the
  supported path). Plain loops — the performance-parity contract holds.
  Covered by `tests/pick_filter_test.gd` (17 assertions).
- **fx expression autocomplete**: expression fields are now single-line CodeEdits with
  completion popups (sheet variables, sheet functions, host members — the same candidate
  source as the GDScript-block editor), on top of the existing live validation. Newlines
  can never reach the stored value.
- **External-sheet file watcher**: GDScript-backed sheets track their file's mtime; when
  the editor regains focus after an outside edit (script editor, git, another tool), a
  prompt offers "Reload (re-import + event lifting)" vs "Keep Editor Version" (asked once
  per change). Save/open keep the timestamp in sync.
  Both covered by `tests/fx_completion_watch_test.gd` (10 assertions).

### Docs & demo final sweep
- **EDITOR-UI-SPEC §3 rewritten** as a roadmap-status section (everything planned has
  shipped; only pick-filter compilation, ƒx autocomplete, bookmarks, includes, and the
  MCP candidate remain open) and the **C3 parity matrix updated** (inline code blocks,
  behaviors, object icons, per-comment colors → Matched).
- **Theme token spec** gains the `behavior_accent_color` row; the two `docs/spec/` design
  studies are banner-marked as reference documents pointing at the live specs.
- **Demo refreshed**: `demo/README.md` rewritten for Godot EventSheets (asset map, golden
  regeneration workflow, toolbar theme switcher/theme editor); `demo/scenes/player.tscn`
  now actually attaches the generated script (with a collision shape) instead of being an
  empty node; the committed `player_generated_test_output.gd` byproduct is removed and
  `compile_demo_test` writes to `user://` so tests never dirty the repo again; orphan
  `.uid` cleaned up.

### Release housekeeping: zero test failures, paste-GDScript-as-events, migration guide
- **The full test suite is GREEN for the first time: 594 passing, 0 failures.** The four
  legacy `event_sheet_editor_test` failures are fixed for real:
  - the built-in demo sheet stamped its ACEs with provider "Core" while reflection
	registers the demo actor as `EventSheetDemoGameplayActor` — the resolver now matches
	by name (and no longer depends on registry refresh order), so demo rows render
	"On Died"/"Take Damage 10" again;
  - non-event spans (comments/variables/blocks) clamp 2px tighter, accounting for the
	chip rect's expansion — long comments stay inside the row width at any zoom;
  - the context-menu test re-acquires live row data between undoable edits (snapshot
	restore replaces row resources; the old assertion toggled an orphan).
  Only the long-known harmless tail segfault remains (after the summary prints); CI now
  fails on ANY `[FAIL]`.
- **Paste GDScript → events**: pasting raw GDScript from anywhere converts through the
  open-as-sheet pipeline — trigger functions ACE-lift into real events, declarations
  become variable rows, everything else lands as verbatim GDScript blocks (the lossless
  rule). Non-code clipboard text falls through to the normal paste paths untouched.
  Covered by `tests/gdscript_paste_test.gd` (9 assertions).
- **C3 migration guide** (`docs/C3-MIGRATION-GUIDE.md`): concept map (behaviors, layouts,
  picking, expressions) + common System vocabulary table + habits that transfer vs.
  habits to relearn.
- **Perf re-baseline** (10,801 flat rows): sheet build ~490 ms, zero per-row widgets,
  visible draw window 8 rows — the virtualization contract holds post-1.0-features.

### 1.0 feature-complete: visual completeness, export integrity, theme editor, rename
- **The plugin is now "Godot EventSheets"** (plugin.cfg, README, release artifacts —
  internal class names keep the EventForge prefix as the engine codename). Release zips
  are now `godot-eventsheets-<v>.zip` / `godot-eventsheets-samples-<v>.zip`.
- **Comments reach C3 parity**: multiline comment rows (one cell per line, row height
  follows), **per-comment background colors**, a comment dialog (multiline text + color
  picker — double-click multiline comments or use "Edit Comment…"; single-line comments
  keep fast inline editing), and **comment ↔ action-cell conversion** ("Attach Comment To
  Event Above" / "Detach Comment To Row"). Action-cell comments render per line inside the
  action lane, edit via double-click, and **compile to `#` lines inside the body**;
  top-level comments also compile as real comment text (the last "TODO: row type" case for
  comments is gone). Covered by `tests/visual_completeness_test.gd` (13 assertions).
- **Export-integrity hook**: an `EditorExportPlugin` recompiles every event sheet when an
  export starts (loud per-sheet errors on failure; GDScript-backed sheets skipped — their
  `.gd` is already the truth). The same pass is a static headless API
  (`EventSheetExportIntegrityPlugin.recompile_all_sheets`), tested in CI.
- **Visual theme editor** (the final planned phase): toolbar "Theme Editor…" opens a live
  workbench — a real viewport rendering a sample sheet on the left, and a **reflectively
  generated token form** on the right (every exported Color/float/int/bool on the style
  resources gets a control automatically, so future tokens appear with zero editor
  changes). Edits preview live on a sandboxed copy; "Apply To Current Sheet" is undoable;
  "Save As Preset…" writes a shareable `.tres`. Covered by
  `tests/release_hardening_test.gd` (13 assertions).
- **Stale code removed**: the dead `else_codegen`/`loop_codegen`/`expression_parser`
  compiler stubs (superseded by real implementations), the unreferenced `binding/`
  scaffold, and the unused `LoopRow`/`EventGroupReference` model stubs.

### Runtime addon bridge + instance-backed ACEs, release automation, docs refresh
- **`EventForgeBridge.register_script_as_provider` is real**: scripts registered from code
  (other plugins, tools, tests) join the ACE vocabulary exactly like
  `res://eventsheet_addons/` scans — static API (works without the autoload), deduped,
  unregister supported, `providers_changed` emitted.
- **Instance-backed addon ACEs**: addon *methods without* `@ace_codegen_template` used to
  compile to nothing; applying one now bakes a call through a per-provider member
  (`__eventsheet_provider_<Class>.method({args})`), and the compiler declares each used
  provider **once** as a plain owned instance (`var __… := Class.new()`). Template-less
  addon ACEs therefore compile and run in exported games with zero EventForge dependency
  (the parity contract holds — asserted in tests). Demo addon gained `announce_heal` as a
  living example. Covered by `tests/runtime_provider_test.gd` (10 assertions).
- **GitHub Actions**: `ci.yml` (every push/PR: import must be clean, headless-safe suite
  gates, full suite checked against the known pre-existing failures) and `release.yml`
  (tag `v*` or manual: test gate → version stamped into `plugin.cfg` → publishes a GitHub
  Release with `eventforge-<v>.zip` (addons-only, Asset Library layout) and
  `eventforge-samples-<v>.zip` (behavior packs + demo) with generated notes).
- **Docs folder refreshed**: `SPEC.md` rewritten (it still pointed at the deleted widget
  editor; now documents the real architecture, the implemented translation matrix, and
  the zero-runtime boundary); Auto-ACE and C3-workflow status docs updated to current
  truth; the early progress report is marked as a historical snapshot; theme-editability
  and alignment guides gained the newer facts (preset switcher, Godot-adaptive default,
  semantic tokens, icon advance, drag-resizable divider).

### ACE-level import lifting (reverse template matching)
- **Opening EventForge-generated GDScript as a sheet now lifts it back into real events.**
  Trailing lifecycle trigger functions (`_ready`/`_process`/`_physics_process`) parse into
  EventRows: conditions and actions **reverse-match the builtin codegen templates**
  (`{param}` placeholders become named captures; params round-trip as strings, including
  `not (...)` negation), and statements matching no template become in-flow GDScript
  blocks so the event still lifts.
- **The lossless rule still always wins**: the lift is all-or-nothing per file and kept
  only when recompiling the lifted sheet reproduces the source **byte-for-byte**;
  otherwise everything reverts to verbatim block rows. Non-trigger functions and unknown
  layouts simply stay blocks. Implemented in `EventSheetACELifter`
  (`addons/eventforge/importer/ace_lifter.gd`); covered by `tests/ace_lift_test.gd`
  (11 assertions).
- **README rewritten** around the actual feature set: every major phase (editor parity,
  compiler depth, GDScript pairing, zero-config extensibility, behaviors/packs), project
  layout, verification commands, and the remaining road to 1.0.

### Pairing polish: reverse provenance, live ƒx validation, row-cell icons
- **Reverse provenance** — the pairing loop now runs both directions: clicking a line in
  the GDScript panel **selects the sheet row that generated it** (most-specific source-map
  range wins; clicking inside an in-flow block selects its enclosing event). Built on the
  new `EventSheetViewport.select_resource()`, which also scrolls the row into view.
- **Live ƒx expression validation** — expression parameter fields compile-check on every
  keystroke against the sheet context (variables, host members, behavior `host`), tinting
  red with an explanatory tooltip when the text is not a valid GDScript expression
  (`EventSheetGDScriptLint.lint_expression`).
- **Object icons in row cells** (C3's strongest visual cue): condition/action/trigger
  cells draw their ACE's icon before the object label — addon `@ace_icon` textures, Godot
  class icons for node-typed ACEs, member glyphs otherwise; Core/System uses the editor's
  Tools glyph. Same resolver as the picker, cached per provider/ACE (misses for
  not-yet-loaded providers are not cached, so addon hot-loads self-heal). Span measurement
  accounts for the icon advance, so hit-testing stays exact.
- The plugin now bundles `addons/eventsheet/icons/eventsheet.svg` (used by the demo addon
  and tests; the project previously had **no** `res://icon.svg`, which made earlier
  icon-path asserts pass vacuously — they are real now).
- Covered by `tests/pairing_polish_test.gd` (15 assertions).

### Sample behavior packs (Platformer / Eight-Direction)
- **Two behaviors authored as event sheets ship in `res://eventsheet_addons/`** — editable
  `.tres` sources beside their compiled `.gd` scripts, built by
  `tools/build_sample_behaviors.gd` (also the reference for authoring sheets from code):
  - **PlatformerMovement** (host: CharacterBody2D): ui_left/right movement + gravity every
	physics tick, exported `move_speed`/`jump_velocity`/`gravity`, exposed ACEs **Jump** /
	**Set Move Speed**, and an annotated `jumped` signal publishing as the **On Jumped**
	trigger.
  - **EightDirectionMovement**: top-down ui_* movement with exported `move_speed` and
	**Set Move Speed**.
  Attach either under a CharacterBody2D (Create Node dialog) and it works; its ACEs appear
  in every sheet via the zero-config scanner; GDScript can call it directly
  (`$PlatformerMovement.jump()`). Guarded by `tests/sample_behavior_pack_test.gd`
  (12 assertions), including **no-drift goldens** (committed script == sheet recompile).
- Documented "Using behaviors / sheet code from hand-written GDScript" in the pairing spec
  (typed access, signals/await, extends; the don't-hand-edit-generated-files rule and the
  host lifecycle note).

### Eventsheet-authored behaviors: expose-as-ACE + sheet-type identity UX
- **Sheet functions can publish as ACEs.** Mark a function `expose_as_ace` (with optional
  display name/category) and the generated script carries the full `@ace_*` annotation
  block — including a default codegen template (`$PatrolBehavior.dash({strength})` for
  behaviors, `dash({strength})` for custom nodes/sheets) and the sheet's icon as
  `@ace_icon`. Drop the compiled script into `res://eventsheet_addons/` and the behavior's
  ACEs appear in every sheet: the **sheet → script → addon loop** is closed (verified by
  parsing the generated script back through the semantic analyzer). Unexposed functions
  emit `@ace_hidden`, making `expose_as_ace` the single publication switch.
- **Sheet-type identity UX** (dual-audience: Godot "custom node with an icon", C3
  "behavior attached to an object"): a slim **identity banner** above the sheet
  (`⚙ PatrolBehavior — Behavior · acts on host: CharacterBody2D`, click to edit), **tab
  badges** (⚙ behavior / ◆ custom node), the column header now reads
  `Conditions — host: <class>` on behavior sheets, a behavior-aware empty-state hint, and
  a new **"Sheet Type…" toolbar dialog** (Event Sheet / Custom Node / Behavior with
  name+icon+host fields) so none of it requires the Inspector. New themable
  `behavior_accent_color` token (soft purple).
- Covered by `tests/behavior_authoring_test.gd` (18 assertions).

### Behavior foundations: host accessor + real signal-trigger codegen
- **Behavior mode** (`EventSheetResource.behavior_mode`): the sheet compiles to an
  attachable **Node component** that acts on its parent — `extends Node`, a typed
  `var host: <host_class>` accessor bound in `_enter_tree` with an attach-time warning,
  and `host_class` reinterpreted as the declared/required host type. Lint/completion
  understand the behavior context (`host.velocity.x` lints clean).
- **Signal-backed triggers now actually connect.** Generated handlers used to rely on
  manual scene wiring; the compiler now emits `<signal>.connect(<handler>)` lines at the
  top of `_ready` (synthesizing `_ready` when no OnReady events exist). Works for self
  signals, **other nodes' signals** (`EventRow.trigger_source_path` → `get_node(...)`
  with source-aware handler names like `_on_platform_landed`), and **custom
  `signal:<name>` triggers** from addons/providers — which previously didn't compile at
  all. Argument signatures are baked at apply time (`trigger_args`), and applying a
  trigger definition now bakes `trigger_id` too (fixing picker-created trigger events
  silently skipping compilation).
- **Compile-time signal validation**: a self-connection is emitted only when the signal
  exists on the script's base class or is declared in a class-level GDScript block;
  otherwise it's skipped with a precise warning (emitting blindly produced a script that
  didn't parse — caught on the demo, whose CharacterBody2D sheet used OnBodyEntered).
- **Demo golden regenerated from the compiler** — `compile_demo_test` passes for the
  first time (pre-existing failures drop from 5 to 4). Covered by
  `tests/behavior_foundations_test.gd` (16 assertions).

### Custom node types from sheets + icon support
- **A sheet can now define a custom node type, exactly like GDScript.** Set
  `custom_class_name` (and optionally `custom_class_icon`) on the sheet in the Inspector
  and the generated script emits `@icon("…")` + `class_name X` + `extends Y` — the type
  appears in Godot's Create Node dialog with its icon, instances carry the sheet's
  behavior, and recompiling the sheet updates the class. Future eventsheet-authored
  Behaviors inherit this mechanism automatically (they compile to node scripts).
- **The ACE picker now shows icons** (C3 users expect the object's icon beside its name):
  addon `@ace_icon("res://…")` textures, node-type sections and entries with their Godot
  class icons, and member-kind glyphs (signal/method/property) as fallback — degrading
  gracefully to text-only when unavailable. Resolution is shared
  (`ACEPickerDialog.resolve_definition_icon`) so row rendering can reuse it next.
- Covered by `tests/custom_node_class_test.gd` (8 assertions); demo golden unchanged.

### Sub-event compilation + else/elif chains
- **Sub-events now compile**, nested inside their parent's conditions (C3 semantics): the
  parent's `if` at depth N, its actions and sub-events at depth N+1, recursively. The
  long-standing "row type not yet implemented" placeholder for sub-events/else is gone
  (only pick filters remain TODO).
- **Else / Else-If events chain onto the previous sibling's if** (`elif cond:` / `else:`,
  emitted adjacently); an Else with conditions is treated as Else-If; a chain row without
  a preceding conditioned event degrades to a standalone event with a compiler warning.
- **Event-flow extras compile too**: nested comments emit as `#` comment lines, variables
  dropped into an event's flow become **function-local `var` declarations** (with a warning
  if marked const/exported), and sibling GDScript blocks indent adaptively (pre-indented
  imported code keeps its tabs; flat editor-authored code is indented for its depth).
- **Validity guard**: an `if`/`elif`/`else` whose body emits nothing now gets `pass` —
  condition-only events can no longer produce invalid GDScript (latent bug fixed).
- All emitted rows (sub-events included) get provenance source-map entries. Demo golden
  output is unchanged. Covered by `tests/subevent_compile_test.gd` (12 assertions).

### GDScript-backed sheets: open ANY .gd as an event sheet (losslessly)
- **The Open dialog now accepts `.gd` files.** Opening one imports it as a GDScript-backed
  sheet: the file stays the **single source of truth** (no `.tres` is created), and Save
  compiles back to it. **Untouched files round-trip byte-identically** — guarded by a
  golden test with a deliberately hostile sample (annotations, comments, signals, enums,
  consts, odd formatting, default-param and non-void functions).
- **The lossless rule**: declarations lift to first-class rows only when canonical
  re-emission reproduces the source line exactly (verify-lift — e.g. `var hp: int = 100`
  becomes an editable variable row, `var speed := 5.0` stays verbatim); each top-level
  function becomes its own GDScript block row (per-function provenance); everything else
  is preserved in ordered verbatim blocks. External emission adds no generated header and
  never synthesizes `extends`.
- Events added to a GDScript-backed sheet append as standard trigger functions at the end;
  editing a lifted variable changes exactly its line. Save As `.tres` converts to a normal
  sheet (the `.gd` is left untouched). Covered by `tests/external_sheet_test.gd`
  (11 assertions).

### Performance-parity contract for generated code
- **Hard constraint, now written and guarded**: event sheets compile to GDScript that runs
  exactly as fast as hand-written code — direct statements only (no `call()`/`Callable`
  indirection, no reflection, no plugin classes in output), static types wherever known,
  signals connected once, `await` only when flagged, provenance kept as compiler metadata.
  Spelled out in GDSCRIPT-PAIRING-SPEC (Principles #5) and enforced by
  `tests/codegen_parity_test.gd`, which scans representative compiled output for banned
  indirection patterns and required typing.
- Planned export-integrity hook recorded: an `EditorExportPlugin` recompiling all sheets at
  export so stale generated scripts can never ship (EDITOR-UI-SPEC §3).

### Shareable snippets (cross-project copy/paste)
- **Copying rows now also writes a portable text snippet to the system clipboard**
  (`[eventsheet-snippet v1]` + Godot `var_to_str` data — no JSON, no script paths/UIDs), so
  events/groups/comments/GDScript blocks/variables paste across projects, editor instances,
  and forum/Discord posts. Multi-select serializes only top-most rows (children travel
  inside their parent).
- **Paste detects snippets first** (internal clipboard remains the same-session fallback):
  rows rebuild from whitelisted kinds only, pasted events get **fresh UIDs**, and sheet
  variables the snippet references are **auto-created when missing** (never overwritten),
  so pasted rows compile immediately. Baked codegen templates keep addon ACEs compiling
  without the addon installed; the paste status lists the providers the snippet uses.
- Implemented in `EventSheetSnippet` (documented serialization schema, versioned for
  forward compatibility); covered by `tests/snippet_share_test.gd` (17 assertions).

### GDScript inside the event flow (C3 inline scripting) + lint/completion
- **GDScript blocks can now live inside an event's actions.** Right-click an event →
  **"Add GDScript Action"**: the block renders line-by-line in the action lane (with a
  `GDScript` origin label and value highlighting), moves/deletes/drags as one action, and
  **compiles indented inside the event body** (under the condition `if`), with a provenance
  source-map entry. Disabled blocks are skipped.
- **Compile-check linting** in the block editor: the snippet is validated in a scratch
  script that extends the sheet's **host class** and stubs the sheet's
  **variables/functions**, so `health += 5` and `move_and_slide()` lint clean while broken
  code is flagged (✓/✗ status under the editor, live on every change).
  (`EventSheetGDScriptLint`; Godot doesn't expose the full ScriptEditor analyzer to
  plugins — this is the documented approximation.)
- **Completion**: Ctrl+Space in the block editor offers sheet variables, sheet functions,
  and host-class members; GDScript syntax highlighting in the dialog.
- Covered by `tests/inflow_gdscript_test.gd` (13 assertions).

### Zero-config ACE addons (C3-addon form, no JSON)
- **Drop a script into `res://eventsheet_addons/` and it becomes a project-wide ACE addon
  automatically** — no manifest, no JSON, no per-sheet setup (`EventSheetAddonScanner`,
  recursive, additive to existing providers/default vocabulary). Metadata derives from the
  script: provider name from `class_name`, addon description from the top `##` doc comment,
  per-ACE customization via `@ace_*` annotations.
- **New annotations**: `@ace_display_template("Heal {amount} HP")` (row/picker text),
  `@ace_codegen_template("health += {amount}")` (generated code), and
  `@ace_param_hint(amount expression)` (params-dialog field kinds: expression ƒx,
  variable_reference dropdown…).
- **Custom ACEs now genuinely compile**: codegen templates are baked onto created
  conditions/actions (`codegen_template` export on `ACECondition`/`ACEAction`, honored by
  `ConditionCodegen`/`ActionCodegen` ahead of the descriptor registry — previously
  reflection ACEs had no codegen path at all). Negation wraps baked templates correctly.
- Shipped `eventsheet_addons/demo_health_addon.gd` as the sample addon
  (documentation-by-example); ACE Providers dialog mentions the zero-config folder.
  Covered by `tests/ace_addon_test.gd` (15 assertions).

### GDScript provenance panel (pairing flagship)
- **Click an event, see its GDScript.** The compiler now returns a `source_map`
  ({uid, start, end, kind} with 1-based line ranges; kinds: event / raw / variable /
  function) alongside the output. The new **GDScript** toolbar toggle opens a read-only
  side panel (lazily-built HSplitContainer, line numbers + syntax highlighting) showing the
  generated script; **selecting any sheet row highlights and scrolls to the exact lines it
  compiles to**, and the panel live-refreshes after every edit. Selecting a
  condition/action highlights its event's range; Copy button exports the script.
- Trigger output is byte-identical (the source map is metadata only); covered end-to-end by
  `tests/provenance_test.gd` (13 assertions).

### GDScript pairing batch + spec overhaul
- **Inline GDScript blocks.** Right-click → "Add GDScript Block Below" inserts a
  `RawCodeRow` that renders line-by-line with a `GDScript` badge, moves like any row,
  double-click opens a CodeEdit dialog, and compiles **verbatim at class level** (helper
  funcs, `@onready` vars, signals). Disabled blocks are skipped.
- **Codegen tooltips**: hovering any condition/trigger/action shows the GDScript it
  compiles to (codegen template with parameter values substituted).
- **Expressions are GDScript**: expression fields are explicitly labeled/tooltipped as
  plain GDScript (no DSL).
- **C3 search synonyms** in the ACE picker: "on start of layout"→ready, "every tick"→
  process, "spawn"→instantiate, "destroy"→queue_free, etc.
- **New semantic theme tokens** (previously hardcoded): `invert_marker_color`,
  `object_label_color`, `value_highlight_color`, `cell_hover_color`.
- **Specs**: `EDITOR-UI-SPEC.md` gains an Interaction Contract, a C3 parity matrix, and a
  refreshed roadmap; `EVENTSHEET_THEME_TOKEN_SPEC.md` rewritten with defaults, the
  stability contract, and the Godot editor-theme adapter mapping; new
  `docs/GDSCRIPT-PAIRING-SPEC.md` (guarded by docs_integrity_test).
- Tests: `tests/gdscript_pairing_test.gd`; updated a stale flat-row-count assert for the
  footer rows.

### C3 easy wins: footer add rows, red ✗ invert marker, drop-line arrows, drag ghost (overhaul)
- **"Add event…" footer rows, C3-style.** The sheet ends with a muted "+ Add event…" row and
  every group keeps a "+ Add event to '<group>'…" row as its last child (one level deeper).
  Clicking opens the event picker and the new event is appended into that group / the sheet
  end. Footers are inert affordances: no selection, no context menu, never box-selected, and
  no model resource behind them. Covered by `tests/footer_rows_test.gd`.
- **Inverted conditions show C3's red ✗** (`#FF0000`, bare glyph — no circle behind it).
- **Drop lines have arrowheads at both ends** (row + ACE drags), mirroring C3's insert marker.
- **Drag ghost**: while dragging rows/conditions/actions over a target, a faint (~0.66 alpha)
  label of the dragged content follows the cursor, C3-style.

### C3 visual parity pass: crisp zoom text, solid cell blocks, value highlights, Godot-native theme (overhaul)
- **Text is crisp at every zoom level.** Zoom scales the canvas transform, which blurred
  (zoom-in) or aliased (zoom-out) glyphs rasterized at base size. All renderer text now draws
  at its final physical pixel size in identity space (`_draw_text`), then the zoom transform is
  restored — geometry scales, text stays sharp.
- **Construct 3-style contiguous cells.** Condition/action cells now fill their full line
  (1px hairline), so stacked conditions read as one solid block instead of floating bubbles.
- **Parameter values highlighted in ACE text** (C3-style): numbers, quoted strings, and
  booleans inside condition/action text draw in the value colour (ranges precomputed at span
  build, so the draw path stays cheap).
- **"+ Add action"** (was "+ Add"): muted C3-style affordance on its own line.
- **Godot-native default theme.** Sheets without an explicit theme adopt the running editor's
  colors (base/dark/accent/font via `EventSheetGodotTheme.adapt_to_editor`), so the sheet looks
  part of Godot and follows the user's editor theme. No-op outside the editor (tests stay
  deterministic); explicit sheet themes are untouched.
- Updated 3 legacy layout asserts that still encoded the old same-line "+ Add" placement.

### Collective disable + disabled-row strikethrough (overhaul)
- **Disable/enable the whole current selection at once** with the `X` key — works on a single
  condition/action/event or a multi-selection (disables all if any are enabled, else enables
  all). Covered by `tests/disable_selection_test.gd`.
- **Disabled rows now show a strikethrough**, matching disabled ACEs — so a disabled event,
  group, or comment reads as "commented out", not just dimmed.
- Confirmed (and locked with `tests/subevent_selection_test.gd`) that selecting a sub-event
  does **not** select its parent, while selecting a parent cascades to its sub-events.

### Inline-edit, comment alignment, empty-event & nesting spacing (overhaul)
- **Double-clicking a comment or group name now edits it.** `_begin_edit` falls back to the
  row's first editable span when the click lands on a non-editable part (badge/icon/padding),
  so editing starts from anywhere on a comment/group row, and commits update the resource.
  Covered by `tests/inline_edit_test.gd`.
- **Comments align with the event blocks they annotate** — comment text is indented past the
  trigger/badge column so it lines up with where condition text begins.
- **An event with no conditions shows a clear "Every Tick" cell** in the condition lane (it
  used to be bare text), so deleting the last condition leaves a visible empty event block.
- **Tighter nesting spacing**: a small gap is inserted before event/group blocks that start a
  new sibling/parent-level row, while a parent and its sub-events stay tight — so it reads at a
  glance which events are nested.

### Condition add/delete + "+ Add" placement fixes (overhaul)
- **Adding a condition no longer overwrites an existing trigger.** `append_condition` only
  fills the trigger slot when the event has none; a trigger-type ACE added to an event that
  already has a trigger (e.g. "Every tick") is appended as a condition instead of replacing it.
- **Conditions can be deleted down to zero** (an event may have no conditions — it reads as
  "every tick"). Verified by `tests/condition_edit_test.gd`.
- **"+ Add" on the action lane is now left-aligned on its own line** below the actions, so it
  stays visible at any window width (it was pinned to the lane's far-right edge and scrolled
  off-screen unless the editor was very wide). Line-count math updated to match.

### Comments nestable as sub-events (overhaul)
- **Comments can be nested inside an event as sub-events**, so a comment can describe the
  events beneath it and align under them. Right-click an event → **"Add Comment Sub-Event"**,
  or drag an existing comment onto an event (drop-inside). Nested comments render indented at
  the child level. Covered by `tests/comment_nesting_test.gd`.

### Tree-placed variables (overhaul)
- **Variables can now live in the event tree and be moved like events/comments.** A right-click
  on a row offers **"Add Variable Below"**, which drops a variable directly after that row
  (between/above/under events, inside groups). These tree variables render as variable rows,
  reorder with the normal row drag, are edited via the variable dialog (double-click), and
  compile to class-level declarations honouring the const / private-vs-`@export` flags.
  Implemented by making `LocalVariable` placeable in `sheet.events`; the compiler collects them
  recursively. Covered by `tests/tree_variable_test.gd`. (Sheet-level *global* variables still
  live in their pinned top section.)

### Reorder + variable access toggle (overhaul)
- **Dragging a condition/action to reorder it now works vertically.** The drop position
  (before/after the target cell) was decided by the horizontal cursor position, but cells
  stack vertically — so swapping the top/bottom cell never registered. It now uses the
  vertical position. Covered by `tests/ace_reorder_drag_test.gd` (full press→drag→release).
- **Global variables have a private/global access toggle.** The variable dialog now offers
  "Global (@export — usable outside the script)"; off compiles the variable to a plain
  private `var`, on to `@export var`. Local variables stay private. Covered by
  `tests/variable_export_test.gd`.

### Selection / hover / drag-preview correctness (overhaul — visual)
- **Clicking a condition/action now selects just that cell, hover now shows, and the drag
  drop-line appears** — all three were the same bug: the row layout is cached by geometry, but
  selection, hover, and drag-target state were baked into the cached dict while the cache key
  ignored them. So after a click/hover/drag the renderer read stale state — the whole event
  highlighted instead of the clicked cell, hover never appeared, and the ACE drop-line never
  drew. Selection/hover are now refreshed on every cache read; drag state is part of the cache
  key. Guarded by `tests/layout_state_test.gd`.
- **Clicking outside a cell selects the whole event.** The full-cell click fallback is now
  bounded to the lanes, so clicking the gutter / indent margin selects the event block, while
  clicking a condition/action cell (incl. its padding) selects that ACE.

### Drag-to-resize lane + hover/drag polish (overhaul — visual)
- **Drag the conditions/actions divider to resize the lanes**, C3-style. Hovering the divider
  shows a horizontal-resize cursor; dragging updates the split live and persists the ratio
  onto the sheet's editor style (a default-themed sheet is promoted to a concrete style so it
  saves). The pinned column header tracks the new divider position. Guarded by
  `tests/lane_resize_test.gd`.
- **Per-cell hover.** Hovering a condition or action highlights just that individual cell (a
  clear neutral light tint), not the whole event block — the whole-event highlight read as
  "selected" and was confusing. Whole-row hover remains for single-cell group/comment/variable
  rows.
- **Sub-event drop preview is indented.** Dragging an event so it nests inside another now
  draws the drop line at the child indent level, making "becomes a sub-event" unambiguous.

### Interaction + aesthetic fixes (overhaul — visual)
- **Dragging individual conditions/actions/events now works** (and shows its drop preview).
  The mouse-press that starts an ACE/row drag was not `accept_event()`'d, so the viewport
  stopped receiving motion/release — the drag never tracked and the drop indicator never
  drew. It now accepts the event on drag start. The drop logic (reorder within an event, move
  across events, Ctrl-to-copy) is covered by `tests/ace_drag_test.gd`.
- **Whole condition/action cell is now the click target.** Clicking anywhere on a
  condition/action line (the padding to the right of the text, or the vertical gaps between
  cells) now selects that ACE instead of falling back to selecting the whole event — fixing
  the "it selects the whole event" and "sometimes the action won't select" confusion. Guarded
  by `tests/hit_test_test.gd`.
- **Flat C3/GDevelop-style cells** replace the rounded "bubble" chips: conditions/actions are
  now flat rectangular cells with a subtle fill, a tinted hover fill, and a left accent bar +
  fill when selected (no rounded borders).

### Row rendering fixes (overhaul — visual)
- **Construct 3-style object labels.** Each condition/action/trigger now shows the object it
  acts on before the text (e.g. `System  Is on floor`, `System  Move and slide`) — "System"
  for Core ACEs, the node class for node-typed ACEs — matching the C3 event grammar. Added as
  span metadata (`object_label`) drawn in object colour by the renderer, so span structure
  (and the tests keyed on it) is preserved.
- **Fixed overlapping text on variable / group / comment rows.** Non-event rows fell through
  all of the viewport's span-positioning branches, so every span was placed at the same X and
  rendered on top of each other (e.g. `hp` + the `global` badge drew as `hpglobal`). These
  rows now flow their spans left-to-right.
- **Fixed group-name clipping**: group titles are drawn one font size larger than they were
  measured, so long names (e.g. "Gameplay") were cut off ("Gamepla"). `_measure_span_width`
  now matches the renderer's group-title size.
- Added `tests/row_layout_test.gd` (asserts single-line row spans don't overlap) and a dev
  render harness `tools/render_preview.gd` (renders the viewport to a PNG for visual review).

### GDScript importer — structural round-trip (overhaul — Phase 7)
- **Import GDScript back into an EventSheet.** `GDScriptImporter.import_source/import_script`
  parses the `extends` host class, top-level `@export var`/`var` declarations (with typed
  defaults, via `VariableParser`), and `func` signatures (name + typed params + verbatim
  body, via `FunctionParser`). Each function becomes an `EventFunction` whose body is kept
  as a `RawCodeRow` passthrough.
- **Round-trips through the compiler**: `SheetCompiler._emit_event_body` now emits
  `RawCodeRow.code` verbatim, so an imported sheet re-compiles to the same extends /
  variables / function signatures / bodies (trigger output and the demo golden are
  unaffected — the demo has no raw rows).
- _ACE-level reverse mapping (turning generated `if`/action lines back into conditions and
  actions) is intentionally future work; bodies are preserved as raw code for now._
- **Tests**: `tests/importer_test.gd` covers host-class, typed-variable, and function
  parsing plus the structural round-trip back through the compiler.

### Multiple EventSheet tabs (overhaul — Phase 6)
- **The editor now holds several open sheets at once.** A `TabBar` above the canvas lists
  open sheets; clicking a tab swaps that sheet into the shared virtualized viewport. Each
  tab keeps its own path and **independent dirty state** (shown as a `●` marker on the tab).
- `EventSheetDock` keeps `_current_sheet`/`_current_sheet_path`/`_dirty` as the *active*
  tab's live state (so all existing code is unchanged) and layers a `_open_tabs` list on
  top. `setup()` now opens a sheet in a tab — reusing the existing tab if that sheet is
  already open — and `_refresh_title_strip()` keeps the active tab's persisted state +
  title in sync. Closing a tab activates a neighbour (or a fresh demo when none remain).
- Public API: `get_open_tab_count`, `get_active_tab_index`, `activate_tab`, `is_tab_dirty`.
- **Tests**: `tests/multi_tab_test.gd` covers open/add, re-open de-duplication, per-tab
  dirty isolation across switches, sheet restoration, and close-activates-neighbour.

### Sheet functions (overhaul — Phase 5)
- **`EventFunction` resources now compile to GDScript methods.** `SheetCompiler` emits each
  enabled function as `func <name>(<typed params>) -> void:` with its events compiled into
  the body (empty functions emit `pass`), after the trigger handlers. The condition/action
  body emission was factored into a shared `_emit_event_body` so triggers and functions use
  the same code path (trigger output is byte-identical — no compiler regression).
- **Call-as-action**: new built-in `Core / CallFunction` action ("Call Function") with
  template `{function_name}({args})`, so an event action can invoke a sheet function
  (`do_thing(5)`, `reset()`).
- **Tests**: `tests/sheet_function_test.gd` covers typed-param signature emission, body vs
  `pass`, and the Call Function codegen (with and without args).
- _Authoring UX (a dedicated function-body editor) is deferred; the data model, compiler,
  and call action are in place._

### Sub-event authoring — indent / outdent (overhaul — Phase 4)
- **Reparent events with the keyboard**: **Tab** nests the selected event under the event
  directly above it (moves it into that event's `sub_events`); **Shift+Tab** un-nests a
  sub-event back out to its parent's container, just after the parent. Tab is only consumed
  when the move actually applies, so normal focus traversal still works otherwise.
- New dock handlers `_indent_selected_event` / `_outdent_selected_event` (undoable +
  dirty-tracked) with a `_find_parent_event` resolver, building on the existing
  `_find_resource_location` / sub-event rendering (events already render nested with
  indentation; "Add Sub Event" already exists in the row context menu).
- **Tests**: `tests/sub_event_authoring_test.gd` asserts indent nests under the preceding
  event, outdent restores it after the parent, and both no-op safely at boundaries.

### Custom ACE providers (overhaul — Phase 3)
- **Register your own scripts as ACE sources**: `EventSheetResource` gained an
  `ace_provider_scripts: Array[String]` field. Each registered GDScript is instantiated and
  reflected (via the existing `EventSheetACEGenerator`) so its annotated methods, signals,
  and exported variables appear in the ACE picker as conditions / actions / triggers /
  expressions, grouped under the script's provider id.
- **Dock pipeline**: `EventSheetDock` now builds the live ACE registry from the sheet's
  provider scripts (`_build_sheet_ace_sources` / `_instantiate_provider_script`), falling
  back to the demo source when none are registered. Externally supplied sources
  (`set_auto_ace_sources`) are kept separate (caller-owned, not freed).
- **Management UI**: a new "ACE Providers…" toolbar button opens a dialog listing the
  sheet's providers with Add… (GDScript file picker) / Remove. Public API:
  `add_ace_provider_script`, `remove_ace_provider_script`, `get_ace_provider_scripts`
  (undoable + dirty-tracked). Hot-reloads the picker on change.
- **Tests**: `tests/custom_ace_provider_test.gd` registers a fixture provider and asserts its
  method/signal/property ACEs surface in the registry (and disappear on removal).

### Theme switcher + token coverage (overhaul — Phase 2)
- **Toolbar theme switcher**: an `OptionButton` ("Theme:") listing **Default** plus the
  bundled themes discovered by the new `EventSheetThemePresets`
  (`addons/eventsheet/theme/event_sheet_theme_presets.gd`), which scans
  `res://addons/eventsheet/themes/` and `res://demo/themes/` for `EventSheetEditorStyle`
  resources. Selecting a preset applies it to the current sheet (Default restores the
  built-in palette look); the selection reflects the sheet's active theme on load.
  The existing "Load Theme…" (custom file) and "Reload Theme" buttons remain.
- **Column header is now themed**: added `column_header_background_color`,
  `column_header_conditions_color`, and `column_header_actions_color` tokens to
  `EventSheetEventStyle`; `SheetColumnHeader` resolves them via the new
  `EventSheetViewport.get_event_style()` (with palette fallbacks), so the header respects
  the active theme instead of hardcoded colours.
- **Tests**: `tests/theme_presets_test.gd` verifies preset discovery (all 4 bundled themes
  load as `EventSheetEditorStyle`), name humanization, the new header tokens, and that a
  bundled theme still resolves its event/condition/action styles.

### Construct 3-style ACE picker (overhaul — Phase 1)
- Rebuilt `ACEPickerDialog` (`addons/eventsheet/editor/ace_picker.gd`) as a grouped,
  colour-coded picker matching `EDITOR-UI-SPEC.md` §2.1:
  - **Node-type grouping**: entries group by `ACEDefinition.metadata.node_type` (forwarded
	from built-in descriptors) when set, otherwise by category.
  - **Group colour-coding**: node-type sections amber, Run Context / Triggers / Signals
	teal-green, Variables muted blue, Custom ACEs purple, others neutral.
  - **Per-item type colours**: trigger = green, condition = blue, action = teal,
	expression = purple; a `Type` column reinforces it.
  - **Type-labelled tooltips**: prefixed with the ACE type, e.g. `[Condition]  Is on floor`.
  - **Pre-declared event sections** (`EVENT_PICKER_GROUPS`: CharacterBody2D, Area2D, Node2D,
	RigidBody2D, Timer, AnimationPlayer) shown at the top in event-creation modes; while
	searching, empty sections are hidden so only matching groups remain.
  - **Mode-specific title + header** (Add Event / Add Sub-Event / Add Condition /
	Add Action / Replace …) in the window chrome and body.
  - Provider-aware item labels (built-in `Core` ACEs show just their name; custom-provider
	ACEs append the provider).
- **Tests**: `tests/ace_picker_logic_test.gd` covers the grouping/colour/mode/title/tooltip
  logic headlessly (without opening the popup window).

### Construct 3-style ACE parameter & expression dialog (overhaul — Phase 1)
- Rebuilt `ACEParamsDialog` (`addons/eventsheet/editor/ace_params_dialog.gd`) per
  `EDITOR-UI-SPEC.md` §2.2:
  - **Parameter descriptions** now render below their control (not just as a tooltip).
  - **Variable-reference params** (`hint == "variable_reference"`) render a dropdown of the
	sheet's variables (provided by the dock via a callable). When no variables exist, a
	disabled "No variables available" field is shown, **OK is disabled**, and the hint tells
	the user to add a variable first.
  - **Expression params** (`hint == "expression"`) render an inline `ƒx` button that opens
	an **Insert Expression** picker (EXPRESSION ACE definitions, grouped by node type and
	colour-coded like the main picker). Selecting one inserts its code template with default
	params substituted into the field.
  - **◀ Back** button (shown only when the dialog was opened from the picker) returns to the
	picker with the original mode/context, via a new `back_requested` signal handled by the
	dock.
- `EventSheetDock` now passes the ACE registry + a sheet-variable-name provider into the
  dialog and wires the Back flow (`_on_ace_params_back_requested`,
  `_collect_sheet_variable_names`).
- **Tests**: `tests/ace_params_logic_test.gd` covers expression-template substitution,
  variable-name resolution, back/re-edit flags, hint text, and value extraction headlessly.

### Construct 3-style column header (overhaul — Phase 1)
- Added a pinned **Conditions / Actions** column header (`SheetColumnHeader`,
  `addons/eventsheet/editor/sheet_column_header.gd`) above the scrolling sheet. It mirrors
  the event rows' lane divider (zoom + horizontal-scroll aware) so the two-column grid reads
  from the header straight down through every row.
- Exposed the lane geometry on the viewport: `EventSheetViewport.get_lane_divider_x(width)`
  (now the single source for both row layout and the header), plus `get_canvas_logical_width()`
  and `get_horizontal_scroll()`. The header sits outside the scroll container, so the scroll
  still has a single child (viewport).
- **Tests**: `tests/column_header_test.gd` guards the lane-divider math (the alignment
  contract) and header binding/band reservation headlessly.

### Keyboard authoring workflow (overhaul — Phase 1)
- Completed the `EDITOR-UI-SPEC.md` §2.4 keyboard map in the dock's `_unhandled_key_input`,
  adding the missing shortcuts: **Ctrl+Shift+S** (Save As), **Ctrl+E** (Add Event),
  **Ctrl+Shift+V** (Add Variable), **Ctrl+Shift+C** (Add Condition), **Ctrl+Shift+A**
  (Add Action), **Q** (Add Comment), **G** (Add Group), **Ctrl+D** (Duplicate Event) —
  alongside the existing Ctrl+C/V/S/Z/Y/O, Delete, Enter/F2.
- New dock handlers `_on_add_comment_requested`, `_on_add_group_requested`,
  `_on_duplicate_requested` (deep-clone + fresh `event_uid` via `_assign_fresh_event_uids`),
  all routed through the existing undoable-edit + insert-below-selection pipeline.
- **Text-field guard**: a `_text_field_has_focus()` check suppresses authoring shortcuts
  while a `LineEdit`/`TextEdit`/`SpinBox` owns focus, so typing never triggers actions.
- **Tests**: `tests/keyboard_actions_test.gd` drives the handlers and asserts add-group,
  add-comment, duplicate-no-op-without-selection, and duplicate-with-fresh-uid behavior.

### Large-sheet load performance (overhaul — virtualized build)
- **Cached built-in ACE descriptors** in `ACERegistry`: `get_all_descriptors()` /
  `find_descriptor()` previously rebuilt and re-normalized the entire built-in set on
  every call (a hot path when rendering sheets that reference fallback/unknown ACEs).
  Built-ins are now normalized once and indexed for O(1) lookup. Added `clear_cache()`.
- **Lazy event-row spans**: event rows now build their (expensive) visual spans on demand
  — only when laid out, hit-tested, or selected — instead of eagerly for the whole sheet.
  Row heights/metrics are derived up front from a cheap precomputed line count
  (`EventRowData.line_count`, `EventSheetViewport._count_event_lines()`), so the full sheet
  is measured without building any spans. Sheets with ≤ `EAGER_SPAN_LIMIT` (1500) rows
  still build eagerly, so small-sheet behavior is unchanged.
- **Result**: loading a 10,000-event sheet dropped from ~19,050 ms to ~370 ms (~52×).
  Scrolling already drew only the visible row range; now the build is virtualized too.
- **Box selection** now culls rows by the cheap precomputed metrics before building
  layout, so a box drag never builds layout/spans for the whole sheet.
- **Tests**: `tests/event_lazy_spans_test.gd` guards the line-count↔span invariant across
  event shapes plus the lazy/eager and hit-test/selection-trigger behavior;
  `tests/perf_smoke_test.gd` guards the 10k-row load budget + virtualization invariants;
  `tests/run_perf.gd` runs these headless-safe checks.

### Editor architecture consolidation (overhaul — Phase 0)
- Removed the parallel Control-widget editor prototypes (`EventRowUI`, `GroupRowUI`,
  `CommentRowUI`, `VariableRowUI`, `SheetToolbar`) and the unimplemented stub files
  (`ACEPalette`, `ActionPicker`, `ConditionPicker`, `DualViewSwitcher`, `ElseRowUI`,
  `ExpressionEditor`, `GDScriptPanel`) from `addons/eventforge/editor/`. The custom-rendered
  **virtualized viewport** (`EventSheetDock`/`EventSheetViewport`/`EventRowRenderer`) is now
  the sole editor architecture — it is the only model that scales to tens of thousands of
  events/ACEs without killing editor performance.
- Extracted the removed widget's variable-row text formatting into a standalone, reusable
  `VariableRowFormat` helper (`addons/eventsheet/editor/variable_row_format.gd`); retargeted
  `variable_row_format_test.gd` to it.
- Added `tests/perf_smoke_test.gd`: builds a 10k-event sheet and guards the virtualization
  invariants (no per-row widgets, bounded visible draw window, O(n) build budget).
- Re-anchored `docs/EDITOR-UI-SPEC.md`, `AGENTS.md`, and
  `docs/EVENTSHEET_ARCHITECTURE_SLICES.md` to the single virtualized architecture.

### ACE picker discoverability improvements (issue #54 – slice 2)
- **Live search/filter in ACE picker**: A `LineEdit` search box (`ACEPickerSearch`) added
  below the picker title.  Typing filters visible entries by list name, description, or
  node type in real time.  Pre-declared empty group headers are hidden when a filter is
  active so only groups with matches appear.  Clearing the search box restores the full
  grouped list.  Stored picker flags (`_ace_picker_include_triggers/conditions/actions`)
  allow the search handler to re-populate with the correct mode filters.
- **Per-item ACE type colour-coding**: Each entry in the picker tree is now tinted by its
  ACE type (triggers = soft green, conditions = soft blue, actions = soft teal) via the
  new `_get_picker_item_color()` static helper.  Group headers retain their existing
  colour scheme; item tints are deliberately softer to avoid visual conflict.
- **Type-labelled tooltips**: Picker item tooltips now carry an ACE type prefix
  (`[Trigger]`, `[Condition]`, `[Action]`) from the new `_get_ace_type_label()` helper,
  giving an at-a-glance type signal without touching the item label text.
- **Expanded built-in node-type ACEs**: Fourteen new Core ACEs added with `node_type` set
  so they appear in the correct class section in the picker:
  - `Node2D` — `SetPosition2D` (action), `SetRotationDeg` (action)
  - `CharacterBody2D` — `MoveAndSlide` (action), `SetVelocity2D` (action)
  - `Area2D` — `OnAreaEntered` (trigger)
  - `RigidBody2D` — `ApplyCentralImpulse` (action)
  - `Timer` — `StartTimer` (action), `StopTimer` (action), `IsTimerStopped` (condition),
	`OnTimeout` (trigger)
  - `AnimationPlayer` — `PlayAnimation` (action), `StopAnimation` (action),
	`IsAnimationPlaying` (condition), `OnAnimationFinished` (trigger)
- **Expanded `EVENT_PICKER_GROUPS`**: `Node2D`, `RigidBody2D`, `Timer`, and
  `AnimationPlayer` added to the pre-declared group list so their sections are always
  present at the top of the "Add Event" picker (node-type groups precede logical
  categories).
- **Tests**: Added assertions for all new built-in node-type groups, per-item colour
  helper, ACE type label helper, and search filter behaviour (filter match + empty-filter
  group count).
- **Docs**: Updated `EDITOR-UI-SPEC.md` section 2.1 and `SPEC.md` section 7 to document
  the search box, per-item colouring, type-labelled tooltips, expanded built-in ACE set,
  and updated pre-declared group list.

### Workspace shell polish (issue #59 – slice 4)
- **Central split composition**: Replaced fixed `HBox + VSeparator` canvas/inspector
  layout with a named `HSplitContainer` (`WorkspaceSplit`) so the editor body reads
  as a dedicated workspace split surface.
- **Canvas resource-tab framing**: Added `SheetCanvasResourceTab` inside
  `SheetCanvasDocumentStrip` so active sheet title + dirty state are framed as an
  editor-style document tab rather than plain strip labels.
- **Inspector surface flattening**: Inspector shell now uses square-corner framing to
  better match the main workspace/editor shell composition.
- **Tests/docs**: Extended workspace-shell and editor tests to assert split-shell and
  resource-tab presence, and updated editor UI spec for the new framing model.

### Workspace document framing improvements (issue #59 – slice 3)
- **Toolbar resource-path context**: Added a dedicated path hint label in the toolbar
  top row so the currently opened EventSheet resource path is always visible.
- **Canvas document strip**: Added `SheetCanvasDocumentStrip` at the top of the main
  canvas surface to provide document-like framing in the editor body:
  - `EventSheetResource` kind tag
  - active document title
  - dirty indicator dot
  - full resource path / unsaved hint
- **Central surface composition**: Updated the main canvas shell from rounded utility
  card framing to a flatter document surface with a top strip + content body margin,
  making it feel more like a dedicated workspace document.
- **Tests/docs**: Added test coverage for toolbar path formatting and new document-strip
  presence, and updated the editor UI spec with path/document-strip behavior.

### Workspace shell improvements (issue #59 – slice 2)
- **Toolbar flush at top**: Removed the 8px outer margin that wrapped the toolbar.
  The toolbar now spans the full workspace width with zero margin above or beside it,
  matching the Godot Script editor layout rather than a dock widget.
- **Status bar at bottom**: Added a full-width `PanelContainer` status bar at the very
  bottom of the workspace (thin, 1 px top border). All operation feedback messages
  (save, compile, add/delete events/variables/groups) are now routed here via the new
  `_set_status()` helper rather than appearing in the toolbar header row.
- **Save / Save As**: Added `Save` and `Save As…` buttons to the toolbar action strip.
  - `Save` writes the current sheet to its existing resource path; falls back to Save As
	for unsaved in-memory sheets.
  - `Save As…` opens a FileDialog to pick a path; updates `resource_path` on success via
	`take_over_path()`.
  - Both are disabled when no sheet is loaded.
  - Keyboard shortcuts: `Ctrl+S` (Save), `Ctrl+Shift+S` (Save As).
- **Dirty state tracking**: `EventSheetEditor._is_dirty` is set by `_mark_dirty()` on
  every mutation (add/replace/delete events, conditions, actions, variables, groups,
  condition inversion) and cleared by `_clear_dirty()` on sheet load or successful save.
- **Dirty indicator (●)**: Amber dot `●` appears next to the sheet name in the toolbar
  top row when `_is_dirty` is true; hidden when the sheet is clean.  Controlled via the
  new `SheetToolbar.set_dirty(dirty: bool)` method.
- **Toolbar label rename**: Toolbar header label changed from `EventForge` to `EventSheet`
  to correctly identify the workspace type rather than the plugin brand.
- **Toolbar corner radius**: Set to 0 (flush top) to match the full-width flush-at-top
  layout; previously used a 6 px all-around radius that implied a floated card widget.
- **Tests**: New `tests/workspace_shell_test.gd` covers toolbar save signals, dirty
  indicator visibility, Save/SaveAs button enabled state, and `_mark_dirty` / `_clear_dirty` toggling.
- **Docs**: Updated `docs/EDITOR-UI-SPEC.md` section 2.4 to document the new shell
  structure, toolbar layout, save flow, dirty tracking, and keyboard shortcuts.

## [0.1.0] - 2026-05-15
- Initial EventForge Phase 1 scaffold.
- Added resource model, bridge, ACE registration, and Phase 1 compiler path.
- Added demo project, hand-authored sheet, golden generated output, and test harness.
