# Spec — Code-Free Condition Logic (stop forcing a drop to GDScript)

**Status:** proposed · **Date:** 2026-06-22

**Motivation (user, verbatim):** *"coming from Construct, I'm surprised there's no condition blocks for the conditions that would be if statements, especially for comparing values or vars! … it is currently falling behind Construct when it comes to code being legible and easier to understand via event sheets."* And: *"the aim is that users are expecting to work code-free; having to use GDScript blocks for things underwrites that purpose."*

The objective is **code-free authoring**, not merely legibility: every raw GDScript block a user is *forced* into is a failure of the core promise. The shoot logic below should be expressible entirely as condition + action blocks.

---

## 1. The problem

The flagship `platformer_shooter` showcase expresses a whole piece of game logic as one raw GDScript block in the **action** lane, with an **empty condition lane** (`tools/build_examples.gd:555-561`):

```gdscript
if Input.is_action_pressed(&"ui_accept") and $Player/WeaponKit.can_fire():
    $Player/WeaponKit.fire()
    var __dir = $Player/PlatformerMovement.facing_direction()
    var __shot = load("res://demo/showcase/shot.tscn").instantiate()
    __shot.position = $Player.position + Vector2(32.0 * __dir, -6.0)
    __shot.rotation_degrees = 0.0 if __dir >= 0 else 180.0
    add_child(__shot)
    __shot.add_to_group("shots")
```

A Construct user reads this as a broken promise: the `if` should be **conditions on the left**, the body **actions on the right**. Worse, the *demo itself* teaches "drop to GDScript."

## 2. What already works (be honest)

Comparison conditions exist and compile to clean `if` heads:

| Condition | Template | Defined |
|---|---|---|
| **Is Action Pressed** | `Input.is_action_pressed(&{action})` | `addons/eventforge/registration/modules/core_aces.gd:58` |
| **Compare Variable** | `{var_name} {op} {value}` | `core_aces.gd:65` |
| **Compare Values** | `{a} {op} {b}` | `addons/eventforge/registration/modules/system_aces.gd:59` |

Operators come from the shared dropdown (`ace_factory.gd:54`). The `starfall` showcase already authors these the right way (`tools/build_examples.gd:310-322`): conditions `Compare Variable (state == PLAYING)` + `Is Action Pressed (ui_left)` on the left, a movement action on the right. Each enabled condition is compiled by `ConditionCodegen.generate_condition` (`addons/eventforge/compiler/condition_codegen.gd:8`) and AND-joined into the event's `if` head by the event-body emitter; inversion wraps `not (...)` (`condition_codegen.gd:25`).

**So this is not "comparisons are missing."** It is three things: (a) one genuine capability gap, (b) showcases that teach the wrong pattern, (c) discoverability.

## 3. Root cause — the one missing condition

Decompose the shoot block's `if` head:

- `Input.is_action_pressed("ui_accept")` → **has** a condition (Is Action Pressed). ✓
- `$Player/WeaponKit.can_fire()` → a **boolean method call**. **No condition exists to use an arbitrary boolean expression (or method call) as a condition.** ✗

Because half the `if` cannot be a block, the author drops the *entire row* to GDScript — and once you are writing the `if`, the body goes inline too. **The missing primitive is "use any boolean expression as a condition."** That single gap converts a legible two-condition / two-action row into an opaque code block.

## 4. Proposed fixes (prioritized)

### Fix 1 — P0 — "Expression Is True" condition (the keystone)

A general boolean-expression condition: type any GDScript that evaluates to a bool (`can_fire()`, `health > 0 and shielded`, `%Door.is_open()`).

- **ace_id:** `ExpressionIsTrue`  ·  **label:** `Expression Is True`  ·  **type:** `CONDITION`
- **category:** `General Conditions` (beside Compare Values)
- **params:** `expr` — type `String`, hint `expression` (so it gets ƒx autocomplete), label `Expression`, default `true`
- **codegen template:** `{expr}` — already boolean, drops straight into the `if`
- **inversion:** free — it has no `codegen_on_true`, so the existing path emits `not ({expr})` (`condition_codegen.gd:25`). No separate "Is False" needed.
- **example:** `expr = $Player/WeaponKit.can_fire()` → `if … and $Player/WeaponKit.can_fire():`

This is the keystone: it makes `can_fire()` a block, which unlocks the whole row.

*(Optional P2 sugar: `Variable Is True` / `Is False` for a bool sheet variable, template `{var_name}` — though Compare Variable `(== true)` and Expression Is True already cover it.)*

### Fix 2 — P0 — re-author the raw-`if` showcases to teach conditions

Convert every shipped raw-`if`-in-the-action-lane event into condition rows + action rows. The headline one, `platformer_shooter`'s fire event (`tools/build_examples.gd:555-561`):

- **Conditions:** `Is Action Pressed "ui_accept"` · `Expression Is True $Player/WeaponKit.can_fire()`
- **Actions:** `Weapon Kit: Fire` on `$Player/WeaponKit` (or **Call Method** `fire()`) · `Spawn Scene (Full)` — scene `res://demo/showcase/shot.tscn`, position `$Player.position + Vector2(32.0 * $Player/PlatformerMovement.facing_direction(), -6.0)`, rotation_degrees `0.0 if $Player/PlatformerMovement.facing_direction() >= 0 else 180.0`, group `"shots"`.

Then audit all of `demo/showcase/*` + `tools/build_examples.gd` + the bundled starters for the same anti-pattern and convert each (sizing that list is implementation step 1).

**Drift implication (intended):** this changes the **authoring** (.tres) and therefore the regenerated golden `.gd` (e.g. `facing_direction()` inlined twice instead of a `__dir` local, or a `{uid}` spawn local from Spawn Scene Full). That is an *expected* generated-code change: regenerate via `tools/regenerate_demo_golden.gd` / `tools/build_examples.gd`, then update the golden + `tests/showcase_examples_test.gd` so `drifted=0` holds against the new baseline. The output stays clean, parsing GDScript.

### Fix 3 — P1 — discoverability

- Extend the C3 synonym bridge (`addons/eventsheet/editor/ace_picker.gd:399 C3_SEARCH_SYNONYMS`): `"is true" → "expression"`, `"boolean" → "expression"`, `"if" → "compare"`, `"check" → "compare"`. (It already maps `"compare variable"`/`"compare two values"`.)
- Make Compare Variable, Compare Values, Is Action Pressed and Expression Is True read as one obvious cluster — consider a shared `Logic` (or `Compare`) sub-category so they surface together when a user types "compare", "if", "value", or "variable".

### Fix 4 — P2 — optional "raw if → conditions" nudge

On-save lint / Project Doctor: when a RawCode action's first line is `if <simple comparison>:`, surface an info-tier tip *"this could be a condition row."* Advisory only, never rewrites. Ship only if the simple case can be detected without false positives.

## 5. Before / After (the shoot event)

**Before** — one RawCode action, empty condition lane (illegible, not code-free):

```gdscript
func _on_physics_process(delta):
    if Input.is_action_pressed(&"ui_accept") and $Player/WeaponKit.can_fire():
        $Player/WeaponKit.fire()
        var __dir = $Player/PlatformerMovement.facing_direction()
        var __shot = load("res://demo/showcase/shot.tscn").instantiate()
        __shot.position = $Player.position + Vector2(32.0 * __dir, -6.0)
        __shot.rotation_degrees = 0.0 if __dir >= 0 else 180.0
        add_child(__shot)
        __shot.add_to_group("shots")
```

**After** — conditions on the left, actions on the right, zero raw GDScript:

> **Conditions:** `Is Action Pressed "ui_accept"`  ·  `Expression Is True $Player/WeaponKit.can_fire()`
> **Actions:** `Weapon Kit: Fire`  ·  `Spawn Scene (Full) shot.tscn → in group "shots"`

```gdscript
func _on_physics_process(delta):
    if Input.is_action_pressed(&"ui_accept") and $Player/WeaponKit.can_fire():
        $Player/WeaponKit.fire()
        var __shot = load("res://demo/showcase/shot.tscn").instantiate()
        __shot.position = $Player.position + Vector2(32.0 * $Player/PlatformerMovement.facing_direction(), -6.0)
        __shot.rotation_degrees = 0.0 if $Player/PlatformerMovement.facing_direction() >= 0 else 180.0
        add_child(__shot)
        __shot.add_to_group("shots")
```

Same behavior — now fully authored via condition + action blocks.

## 6. Covenant & backward-compat

- `ExpressionIsTrue` is a **new** ace_id — existing templates untouched, so existing sheets compile byte-for-byte unchanged (drift audit covers it). The duplicate-`provider::ace_id` guard test must stay green.
- `{expr}` is emitted **verbatim** (opaque param) — the user's expression is their responsibility, the same stringly contract as Compare Values / ƒx. No compile-time type check; say so in the ACE description.
- Reverse-lift: Expression Is True is the natural **generic fallback** for an `if <expr>:` head the importer can't match to a specific condition. The lifter already tries most-specific-first, so register it as the lowest-priority condition lift (first verify the importer lifts condition heads at all — see open questions).
- Inversion, AND-joining, sub-events, stateful conditions: unaffected (Expression Is True is a plain, non-stateful term).

## 7. Files to touch

- `addons/eventforge/registration/modules/system_aces.gd` — add the `ExpressionIsTrue` descriptor next to `CompareValues`.
- `tools/build_examples.gd` — re-author `_build_platformer_shooter`'s fire event (and any other raw-`if` events found in the audit) as conditions + actions.
- `demo/showcase/platformer_shooter.{tres,gd}` (+ any others) — regenerated goldens.
- `addons/eventsheet/editor/ace_picker.gd` — synonym entries (Fix 3).
- `addons/eventforge/importer/ace_lifter.gd` — register Expression Is True as the generic condition lift (if condition-head lifting exists).
- Tests: new `tests/expression_is_true_test.gd`; refresh `tests/showcase_examples_test.gd` golden.

## 8. Testing plan

- **Unit:** ExpressionIsTrue registered; compiles `$X.can_fire()` → `if $X.can_fire():`; negate → `not ($X.can_fire())`; output is parity-clean.
- **Showcase:** re-authored `platformer_shooter` compiles + parses + instantiates (`showcase_examples_test`); `drifted=0` against the regenerated golden.
- Full headless suite green; editor import clean.

## 9. Open questions

- Does the importer lift condition heads (`if a == b:`) back into condition ACEs today, or only actions/triggers? If yes, slot Expression Is True last; if no, it is forward-only (note it).
- Exact ace_id of "Spawn Scene (Full)", and whether the Weapon Kit pack exposes a "Fire" action vs using Call Method — confirm before re-authoring.
- Inline `facing_direction()` twice, or store it in a sheet-local first (one extra "Set Local" action) to mirror the `__dir` local exactly? (Cosmetic; inlining is simpler.)
