# SPEC - Behaviour-as-ACEs parity: functions + behaviour-building vocabulary so bundled packs need no GDScript blocks

**Status:** SHIPPED (the vocabulary + function-system foundation is built: host-targeting `{host.}`, physics/trig vocabulary, the function system, reverse-lift; five bundled packs compile at zero RawCode). Kept as the design record for those systems. **Author trigger:** the user observed that the Platformer Movement behaviour's *GDScript is more readable than its event-sheet form*, that too much of a behaviour stays a `RawCodeRow`, and that "the eventsheets are not ready until the addons made with eventsheets are not using GDScript blocks anymore but fully realised as ACEs." This spec closes that gap.

**Covenants honoured:** plain typed GDScript output; byte-stable regeneration of *unchanged* packs; unique `ace_id`s (a guard is **added** here - see §9, it does not exist today); reverse-lift round-trip stays valid (the lifter change lands *atomically* with the codegen change - see §9); `ace_id`s + templates are public API (compat covenant, `ace_factory.gd:8-9`).

> Line numbers below are as-of the design investigation; they may drift - treat them as "look here," not literal offsets. Every load-bearing claim was re-verified against the working tree during review; corrections from that review are folded in.

---

## 0. The problem, verified against the code

The critique is correct, and three structural gaps in the compiler force the RawCode fallback:

- **No bundled pack is authored purely as ACE rows.** All **31** pack builders (`tools/pack_builders/*.gd`; the 32nd file, `_lib.gd`, is a shared helper, not a pack) use at least one `RawCodeRow`. `platformer.gd` keeps its whole `_physics_process` core as one RawCode block under an `OnPhysicsProcess` trigger (`platformer.gd:158-197`) and every exposed action (`jump`, `jump_released`, …) as a RawCode body (`:200-233`). `flash.gd` has **4** RawCode blocks (signal `:21`, tick `:27`, `flash()` body `:54`, `stop_flash()` body `:65`). The lifted sheet adds a trigger label and nothing else - strictly *less* readable than the linear script.

- **Gap 1 - node-scoped ACEs target the wrong object inside a behaviour.** In `behavior_mode` the compiled script is `extends Node` with `var host: <host_class>` (`sheet_compiler.gd:106-119`). But `MoveAndSlide` / `IsOnFloor` / `SetVelocity2D` templates emit **bare** `move_and_slide()` / `is_on_floor()` / `velocity = …` (`core_aces.gd:83,84,63`), and neither `action_codegen.generate_action` nor `condition_codegen.generate_condition` prefixes anything for behaviour mode. So a row authored in a behaviour calls the method on the behaviour Node (`self`), which has no `move_and_slide` - forcing hand-written `host.move_and_slide()`. **This is the #1 blocker; everything else is moot until it lands.**

- **Gap 2 - missing physics primitives.** No apply-gravity action; no component-wise velocity set/add (only whole-`Vector2` `SetVelocity2D`); no "accelerate a velocity component toward a target" action (`MoveTowardValue` is expression-only, `helper_aces.gd:71`); and `GetInputAxis` exists only as an expression with no consuming action (`collection_aces.gd:60`). The platformer writes `host.velocity.x` / `host.velocity.y` independently - inexpressible today.

- **Gap 3 - no function-local *typed* temporary as a row.** `SetLocalVar` emits untyped `var {name} = {value}` (`helper_aces.gd:50`); the platformer's dense interleaved typed locals (`var on_floor := host.is_on_floor()`) force RawCode and defeat reverse-lift.

- **The Function system is ~70% there.** `EventFunction` already carries typed `params: Array[ACEParam]`, a `return_type: int`, `expose_as_ace`, `is_async` (`event_function.gd:22-25`) and compiles to a clean typed `func name(params) -> Ret:` (`sheet_compiler.gd:383,1251-1278`). Missing the C3-defining pieces: per-param **defaults are dropped** (dialog collects only `{id,type_name}`, `function_dialog.gd:145-156`); the expose path **always emits `@ace_action`** regardless of return type (`sheet_compiler.gd:1221`); there is **no call-as-expression** (only the action-only `CallFunction`, `core_aces.gd:76`); and **functions are not a picker category** (only completion-text hints, `ace_params_dialog.gd:1296-1298`).

The spec closes all of this in seven workstreams.

---

## 1. THE FUNCTION SYSTEM (C3 parity)

### 1.1 Already exists - do not rebuild

| Capability | Where | Status |
|---|---|---|
| Typed ordered params | `event_function.gd:22` (`params: Array[ACEParam]`), emitted `sheet_compiler.gd:1259-1278` | ✅ |
| Return type → typed `-> T` | `event_function.gd:24`; `_function_return_type_name` `sheet_compiler.gd:1251-1257` (handles `void` for `TYPE_NIL`, `Variant` for `TYPE_MAX`, `type_string()` for the rest) | ✅ |
| Call as action | `CallFunction` `core_aces.gd:76` → `{function_name}({args})` | ✅ |
| Return value / early | `ReturnValue` `core_aces.gd:74`, `ReturnEarly` `core_aces.gd:75` | ✅ |
| Expose as project-wide ACE | `expose_as_ace` + `_emit_expose_annotations` `sheet_compiler.gd:1215-1247` | ✅ **action-only** |
| `ACEParam.default_value` field | `ace_param.gd:26` (under `addons/eventforge/resources/`) | ✅ present, **unused by the function path** |

### 1.2 The expose-type mapping (CORRECTED - single type per function)

> **Why single-type:** the provider pipeline appends exactly **one** `ACEDefinition` per method (`ace_generator.gd:69`) and stores a single last-wins `forced_ace_type` (`semantic_analyzer.gd:135-142`). Emitting both `@ace_action` and `@ace_expression` yields **one** ACE of whichever parsed last - not two. A true dual-contract would require the generator to emit multiple definitions per method and the analyzer to accept a *set* of forced types - out of scope. So expose maps to a single type.

Branch `_emit_expose_annotations` (`sheet_compiler.gd:1215-1247`) **three ways** on `return_type`:

| `return_type` | Annotation emitted | Picker surface |
|---|---|---|
| `TYPE_NIL` (void) | `## @ace_action` (unchanged → byte-stable for all existing void exposes) | Action |
| `TYPE_BOOL` | `## @ace_condition` | Condition |
| anything else | `## @ace_expression` | Expression |

The action/discard path for a value-returning function is **already served** by the existing `CallFunction` action (`core_aces.gd:76`) - no second annotation needed. This matches C3: a function with a return type is usable as an expression; calling it for side-effect is the generic "Call function" action.

The shared `## @ace_codegen_template` line (`:1247`) - `$Class.fn({args})` - already returns the value, so it serves expression and condition exposes unchanged.

### 1.3 Per-param typed defaults

Storage already exists (`ACEParam.default_value`). **Defaults are stored and emitted as raw GDScript expression strings, verbatim** - *not* via `_to_code_literal` (which has no `Vector2/Vector3/Color` case; its fallback renders `Vector2(0,0)` as the invalid `(0, 0)`, `sheet_compiler.gd:1526-1557`). Verbatim strings are consistent with every other ACE expression field and sidestep type-specific literal formatting entirely.

Wire it through four sites:
1. **Dialog** (`function_dialog.gd`, `add_param_row` `:115-133`): add a third per-row control - a default-value `LineEdit` (raw expression, matching ACE expression fields). `collect_params()` (`:145-156`) returns `{id, type_name, default}`. Empty default = required param.
2. **Dock apply** (`event_sheet_dock.gd` ~`:6362`): copy `default` into `ACEParam.default_value`.
3. **Codegen** (`_emit_function_params` `:1259-1278`): when `default_value` is non-empty, emit `id: Type = <default_value verbatim>`. **Validate trailing-default ordering** (GDScript requires defaulted params last) - dialog rejects, compiler warns.
4. **Lifter** (`ace_lifter.gd:238-246` + `function_parser._parse_header` `:56-60`): parse `id: Type = default`. **Use a paren-depth-aware splitter** - splitting the param list on `, ` shatters a `Vector2(0, 0)` default. Split the list only at top-level commas (depth 0 outside `()[]{}`), then split each param on the first ` = ` outside parens.

Codegen example: `func deal_damage(amount: int = 10, crit: bool = false) -> int:`

### 1.4 "Set Return Value" affordance (no new ace_id)

`ReturnValue` already exists and emits `return {value}`. The C3 gap is *authoring affordance*, not codegen: when editing inside a value-returning function, the picker surfaces **Return `<value>`** prominently and pre-fills `{value}` with the return type's zero (`0`/`0.0`/`""`/`false`/`Vector2.ZERO`) read from the enclosing `EventFunction.return_type`. A distinct `SetReturnValue` ace_id is **rejected** - it would duplicate `ReturnValue`'s template.

### 1.5 Functions picker category

Functions are completion-text only today (`ace_params_dialog.gd:1296-1298`). Add a synthetic **Functions** provider category to the action/condition/expression pickers, populated at open-time from `sheet.functions` (`event_sheet.gd:65`) plus exposed functions from `res://eventsheet_addons/` providers:

- **void** → **Action** `Call <name>(args)`. Selecting it builds a `CallFunction` action with `function_name` pre-bound and **one typed field per declared param** (default pre-filled) - replacing today's free-text `args` String with positional typed fields, the C3 call-site experience. `args` is assembled at compile by joining the bound fields in declared order. **Compiles to the same `CallFunction` action** → no new compile path, reverse-lift unchanged.
- **bool** → **Condition** (matches the new `@ace_condition` expose, §1.2).
- **value-returning** → **Expression** `<name>(args)`. Inserting it emits `fn(args)` (local same-sheet, a self-method call) or `$Class.fn(args)` (cross-sheet, from the baked `@ace_codegen_template`). The dock distinguishes "my own function" (`sheet.functions`) from "imported provider function" (`ACERegistry` providers) at author time.

`CallFunction` keeps its ace_id and free-text `args` as the manual/fallback path (covenant).

### 1.6 Covenant check (CORRECTED)

- **Void functions:** annotation unchanged → byte-identical → all existing void exposes unaffected.
- **bool/value functions exposed through the EventFunction path:** gain `## @ace_condition` / `## @ace_expression`. This is a **lift-breaking change unless the lifter lands atomically** (`ace_lifter._parse_annotations` `:194-218` has `else: return {}` at `:216-217`, which *rejects the whole annotation block* on any unrecognised directive). The lifter MUST learn `@ace_condition`/`@ace_expression` in the **same commit** (§9).
- **abilities/health "getters" are NOT affected by the §1.2 change** - they are hand-written RawCode blocks already emitting literal `## @ace_condition` / `## @ace_expression` (`abilities.gd:80,132`; committed `abilities_behavior.gd:70,122`). Converting them to EventFunctions is **separate re-authoring** (§5.2) whose success criterion is *byte-identical* regenerated annotations vs the existing hand-written ones (true drift=0) - not "intended drift."
- **Param defaults** change output only for functions that *declare* a default - none do today → existing packs byte-stable until intentionally edited.

---

## 2. BEHAVIOUR-BUILDING ACE VOCABULARY

### 2.1 Structural prerequisite - host-targeting `{host.}` idiom (lands FIRST)

Without this, every physics ACE below still targets `self` inside a behaviour. Reuse the existing optional-prefix regex engine that powers `{target.}` (`action_codegen.gd:54-78`, scope plumbing `:10-41`, `{target.}` site `sheet_compiler.gd:976`):

- New (and retrofitted) node-scoped ACEs use the **`{host.}` optional-prefix** idiom. The compiler passes `host_default = "host"` **only in `behavior_mode`**; `{host.}` resolves to `host.` inside a behaviour and to **empty (self)** everywhere else. One descriptor compiles correctly in both contexts:
  - behaviour: `{host.}move_and_slide()` → `host.move_and_slide()`
  - plain CharacterBody2D sheet: → `move_and_slide()`
- **Autoload carve-out (CORRECTED):** in `autoload_mode` there is no `var host`; pass `host_default = ""` there and in plain-node mode. Only `behavior_mode` supplies `"host"`. Add a compile case proving an autoload sheet with a retrofitted physics ACE emits **bare** (no `host.`).
- **Conditions need net-new plumbing (CORRECTED).** `generate_condition` (`condition_codegen.gd:8-27`) takes **no** target/host param, the call site passes none (`sheet_compiler.gd:888`), and there is **no** condition-side `_params_with_scope_target` to mirror. Add a `host_default` param to `generate_condition` AND change the call site. Resolve `{host.}` **before** the negation wrap (`condition_codegen.gd:25`) so a negated host-scoped condition compiles to `not (host.is_on_floor())`, not `host.not (is_on_floor())`.
- **Retrofit** the existing bare-call node ACEs to `{host.}`: `MoveAndSlide`/`IsOnFloor`/`SetVelocity2D` (`core_aces.gd:83,84,63`), `IsOnWall`/`IsOnCeiling`/`GetWallNormal`/`GetFloorNormal` (`collision_aces.gd:19-22`) + 3D twins (`:45-48`). Output is **byte-stable on non-behaviour sheets** (`{host.}` → empty) and **newly-correct** inside behaviours. Guard with `builtin_ace_compile_test` + `codegen_parity_test`; extend `builtin_ace_compile_test` to fill `{host.}` on the **condition** path too (it currently fills optional prefixes via the action-template path only).

### 2.2 New physics ACEs (CharacterBody2D)

`provider_id = "Core"`, category `"Movement"`, host scope `CharacterBody2D`, `{host.}` idiom. 3D twins mirror into `native_3d_aces.gd` (`CharacterBody3D` + `Vector3`).

| ace_id | Label | Type | Params | Template |
|---|---|---|---|---|
| `SetVelocityX` | Set Velocity X | ACTION | `x: expr "0.0"` | `{host.}velocity.x = {x}` |
| `SetVelocityY` | Set Velocity Y | ACTION | `y: expr "0.0"` | `{host.}velocity.y = {y}` |
| `AddVelocity` | Add To Velocity | ACTION | `delta_v: expr "Vector2(0, 0)"` | `{host.}velocity += {delta_v}` |
| `ApplyGravity` | Apply Gravity (with terminal velocity) | ACTION | `gravity: expr "980.0"`, `max_fall: expr "1000.0"`, `delta_t: expr "delta"` | `{host.}velocity.y = minf({host.}velocity.y + {gravity} * {delta_t}, {max_fall})` |
| `ApplyGravitySimple` | Apply Gravity | ACTION | `gravity: expr "980.0"`, `delta_t: expr "delta"` | `{host.}velocity.y += {gravity} * {delta_t}` |
| `AccelerateVelocityX` | Accelerate Velocity X Toward | ACTION | `target: expr "0.0"`, `rate: expr "1500.0"`, `delta_t: expr "delta"` | `{host.}velocity.x = move_toward({host.}velocity.x, {target}, {rate} * {delta_t})` |
| `AccelerateVelocityY` | Accelerate Velocity Y Toward | ACTION | `target: expr "0.0"`, `rate: expr "1500.0"`, `delta_t: expr "delta"` | `{host.}velocity.y = move_toward({host.}velocity.y, {target}, {rate} * {delta_t})` |
| `GetVelocityX` | Velocity X | EXPRESSION | - | `{host.}velocity.x` |
| `GetVelocityY` | Velocity Y | EXPRESSION | - | `{host.}velocity.y` |

- `ApplyGravity` bakes the terminal-velocity clamp (the platformer's `minf(…, max_fall_speed)`, `platformer.gd:168`) so one row replaces two RawCode lines; `ApplyGravitySimple` is the unclamped variant.
- `delta_t` defaults to the literal `delta` - valid inside `_physics_process(delta)`/`_process(delta)` trigger bodies (the only place gravity belongs), editable for fixed-step callers.
- These compose with the retrofitted `MoveAndSlide`/`IsOnFloor`/`IsOnWall`/`GetWallNormal`.
- **Open question to confirm at build time:** whether `ApplyGravity`'s default should read `ProjectSettings physics/2d/default_gravity` instead of the literal `980.0`. Recommendation: keep the literal (transparent for non-programmers) + add a separate `GetDefaultGravity` expression for those who want the project value.

### 2.3 New input consumer ACE

`GetInputAxis` is expression-only (`collection_aces.gd:60`). Add the consuming action so "read input into a variable" is a row:

| ace_id | Label | Type | Params | Template | Module |
|---|---|---|---|---|---|
| `SetLocalFromAxis` | Read Input Axis Into | ACTION | `name: "direction"`, `negative: options=input_actions "\"ui_left\""`, `positive: options=input_actions "\"ui_right\""` | `var {name}: float = Input.get_axis(&{negative}, &{positive})` | `collection_aces.gd` |

Turns `var direction := Input.get_axis("ui_left","ui_right")` (`platformer.gd:172`) into one row.

### 2.4 Typed function-local temporaries (closes Gap 3)

| ace_id | Label | Type | Params | Template |
|---|---|---|---|---|
| `SetLocalVarTyped` | Set Local Variable (typed) | ACTION | `name: "temp"`, `var_type: options=[float,int,bool,String,Vector2,Vector3]`, `value: expr "0.0"` | `var {name}: {var_type} = {value}` |

Keeps `SetLocalVar` for inference-style `var x := …`. Both compile function-local (`sheet_compiler.gd:862-867`).

---

## 3. INTERNAL STATE FOR BEHAVIOURS

Three tiers; two already exist, the gap is **UX + one ACE**:

- **Tier 1 - Designer knobs (exported):** sheet `variables` with `exported: true` → `@export var` with full hint support (range/group/tooltip/clamp/on_changed/drawer, `sheet_compiler.gd:1281-1345`). ✅ Used by the platformer for `move_speed`/`gravity` (`platformer.gd:21-52`).
- **Tier 2 - Non-exported class members (internal state):** sheet `variables` with `exported: false` → plain `var name: Type = default` (`sheet_compiler.gd:1311`). ✅ **This is already the coyote-timer mechanism** - the platformer declares `_coyote_timer`/`_buffer_timer`/`_jumps_left` exactly this way (`platformer.gd:54-60`). No new "behaviour variable" primitive needed; the only gap is **authoring UX**: `variable_dialog.gd` should surface the `exported` toggle as an "Internal (not shown in Inspector)" checkbox so a non-programmer can declare `_coyote_timer` without editing a builder.
- **Tier 3 - Function-local temporaries:** `SetLocalVar` / new `SetLocalVarTyped` (§2.4).

The platformer's seven internal fields all map to Tier-2 non-exported variables that already compile correctly.

---

## 4. SIGNALS AS ANNOTATED TRIGGERS (required for zero-RawCode behaviours)

A behaviour that emits a signal cannot be RawCode-free today: `SignalRow` (`signal_row.gd`) carries only `enabled`/`signal_name`/`params`, and `_emit_signal_line` (`sheet_compiler.gd:1385-1394`) emits only `signal name(params)` - no annotations. But a pack's exposed trigger signal needs `## @ace_trigger` / `## @ace_name` / `## @ace_category` (e.g. `flash.gd:21-22`).

**Add annotation fields to `SignalRow`** (`trigger: bool`, `ace_name: String`, `ace_category: String`) and extend `_emit_signal_line` to emit the annotation block when `trigger` is set, with a matching lifter update (the lifter must recognise these directives - same atomicity rule as §9). This makes a declared signal a first-class trigger row and unblocks the `flash` proof (§5.1). It is also the general primitive for "any signal-emitting behaviour authored as ACEs."

---

## 5. PARITY PROOF / re-authoring path

### 5.1 First proof: `flash` (needs §2.1 + §4)

`flash` (`tools/pack_builders/flash.gd`, 4 RawCode blocks) is the simplest viable proof - **once §4 lands** (its `flash_finished` signal is an exposed trigger). It needs no new physics ACE: only host-targeting (§2.1) for `host.visible`, the signal-as-trigger row (§4), and existing `SetVar`/`AddVar`/`CompareVar`/`SetProperty`/`EmitSignal`.

`flash` re-authored, zero RawCode:
- Signal `flash_finished` → annotated `SignalRow` (§4).
- Variables: `interval` (exported), `remaining`/`accumulator`/`flashing` (Tier-2 non-exported).
- `OnProcess` tick as rows: guard on `flashing`/`host != null`; `AddVar remaining -= delta`, `AddVar accumulator += delta`; sub-event `CompareVar accumulator >= interval` → `SetVar accumulator = 0.0` + `SetProperty host.visible = not host.visible`; sub-event `CompareVar remaining <= 0.0` → `SetVar flashing = false` + `SetProperty host.visible = true` + `EmitSignal flash_finished`.
- Functions `flash(seconds: float)` / `stop_flash()` → `SetVar`/`SetProperty` rows.

Compiles to GDScript equivalent to today's `flash` (modulo the `host.` prefix the RawCode already wrote by hand), proving the no-RawCode path on a real bundled pack.

### 5.2 Second proof: `platformer` jump + movement slice

After `flash`: convert the platformer's `jump()`/`jump_released()` functions and the gravity+input+accel slice of the tick using the new vocabulary (§7). Re-author the abilities/health getters as EventFunctions (§1.6) and verify the regenerated `@ace_condition`/`@ace_expression` annotations match the existing hand-written ones byte-for-byte. The per-frame numeric remainder (wall-slide/coyote/buffer interplay) stays RawCode under a documented budget (§5.4).

### 5.3 No-RawCode lint + ratchet test

- **Project Doctor advisory `RawCodeInBundledPack`** (`tools/project_doctor.gd`, none exists today): for any sheet under `res://eventsheet_addons/` (or with `addon_tags`), if `RawCodeRow` count > 0, nudge "This bundled behaviour still uses GDScript blocks - consider re-authoring as ACE rows." **Informational, never blocking.**
- **`pack_rawcode_budget_test.gd`:** a per-pack `{pack: max_rawcode_rows}` ratchet that **fails if a pack EXCEEDS its budget** (prevents regressions); does **not** force zero. `flash` → 0 after §5.1; numeric-kernel packs keep a documented non-zero budget with a reason string.

### 5.4 Honest criterion - when GDScript is the right answer

> Keep GDScript when the body is **per-frame numeric integration with ≥3 interdependent terms updated in one pass** (e.g. a spring `velocity += -k*x - damping*v; x += velocity*delta`), or **tight interleaved control flow over typed locals** where each ACE row would be a one-line wrapper around a single arithmetic op. ACEs win for **discrete game logic** (state transitions, signal emission, conditionals, calling sub-behaviours); GDScript wins for **continuous math kernels**.

By this rule: `flash`, `follow` (mostly), `timer`, `eight_direction` input mapping, and the platformer's *discrete* parts convert cleanly; `spring`'s integrator, `juice`'s squash spring, `sine`, and the platformer's gravity+accel inner loop may stay GDScript (and `ApplyGravity`/`AccelerateVelocityX` shrink even those to a couple of rows). **Goal: zero *gratuitous* RawCode under the ratchet - not dogmatic zero.** The title's "no GDScript blocks" means no *gratuitous* blocks.

---

## 6. PROGRESSIVE AUTHORING ("ready-made ACEs, progressively detailed")

Tie the new capabilities into the existing **Behavior Component starter** (`event_sheet_dock.gd:_build_behavior_component_starter` ~`:6785`, guarded by `behavior_starter_test.gd`):

1. **Scaffold (L0):** "New Behaviour" → starter sheet with `behavior_mode=true`, host-class picker (CharacterBody2D/Node2D/Area2D/CanvasItem), one exported knob, one `On Ready`, one declared signal. (Exists.)
2. **Add movement (L1):** a one-click **"Add movement skeleton"** that inserts an `OnPhysicsProcess` tick pre-filled with the new physics ACEs in canonical order - `ApplyGravity` → `SetLocalFromAxis direction` → `AccelerateVelocityX` → `MoveAndSlide` - all host-targeted. A working CharacterBody2D mover with zero typing; tune the exported knobs after.
3. **Add reusable logic (L2):** "Add function" (the §1 dialog) for `jump()`/`dash()`, each exposable so the behaviour publishes its own vocabulary project-wide.
4. **Refine (L3):** open any inserted row, edit params via the typed picker; functions gain typed params + defaults; value-returning functions appear in ƒx fields.

Document as a `docs/GUIDE-../GUIDE-RECIPES.md` recipe + a showcase sheet.

---

## 7. BEFORE / AFTER (platformer slice)

**BEFORE - RawCode (`platformer.gd:166-175`, inside the `OnPhysicsProcess` block):**
```gdscript
if not on_floor:
    host.velocity.y = minf(host.velocity.y + gravity * delta, max_fall_speed)
    _air_time += delta
else:
    _air_time = 0.0
var direction := Input.get_axis("ui_left", "ui_right")
var target_speed := direction * move_speed
var rate := acceleration if not is_zero_approx(direction) else deceleration
host.velocity.x = move_toward(host.velocity.x, target_speed, rate * delta)
```

**AFTER - pure ACE rows (compiles byte-equivalent via the new vocabulary):**
- `On Physics Process` (trigger, exists)
  - Sub-event `Is On Floor` **negated** (`{host.}is_on_floor()`, §2.1) →
    - `Apply Gravity` (gravity=`gravity`, max_fall=`max_fall_speed`) → `{host.}velocity.y = minf(…, max_fall_speed)`
    - `Add Variable _air_time += delta`
  - `Else` → `Set Variable _air_time = 0.0`
  - `Read Input Axis Into direction` (neg `ui_left`, pos `ui_right`) → `var direction: float = Input.get_axis(&"ui_left", &"ui_right")`
  - `Set Local Variable (typed) target_speed: float = direction * move_speed`
  - `Set Local Variable (typed) rate: float = acceleration if not is_zero_approx(direction) else deceleration` (via `InlineIf`, `helper_aces.gd:47`)
  - `Accelerate Velocity X Toward` (target `target_speed`, rate `rate`) → `{host.}velocity.x = move_toward({host.}velocity.x, target_speed, rate * delta)`

**`jump()` AFTER** - a function whose body is `Is On Floor` / `Coyote > 0` conditions gating `Set Velocity Y = jump_velocity` (`SetVelocityY`) + `Emit Signal jumped`, with `elif` branches for wall-jump (`SetVelocityX = get_wall_normal().x * wall_jump_push`) and air-jump - all rows, zero RawCode.

---

## 8. Sequencing

1. **Host-targeting `{host.}` (§2.1)** - unblocks everything; retrofit existing physics ACEs; parity tests. **+ the duplicate-ace_id guard (§9).** *(Land first.)*
2. **Physics + input + typed-local ACEs (§2.2–2.4).**
3. **SignalRow trigger annotations (§4)** + **lifter directive-recognition** (atomic).
4. **Convert `flash` to zero RawCode (§5.1) + budget test (§5.3).** First proof.
5. **Function defaults + three-way expose + Functions picker category (§1)** + lifter param-default round-trip.
6. **Convert platformer jump + movement slice; re-author abilities/health getters as EventFunctions (§5.2).** Second proof.
7. **Progressive-authoring starter actions + recipe (§6); Project Doctor advisory (§5.3); docs; version bump; regenerate; drift=0.**

**Recommended staging:** ship 1–4 (vocabulary + host-targeting + `flash` proof) as one release, then convert remaining packs incrementally under the ratchet - keeps drift/golden churn staged and reviewable.

---

## 9. Implementation guardrails (constraints the design depends on)

These are non-obvious and were each a review finding - do not re-trip them:

1. **One method → one ACE.** No dual action+expression contract (§1.2). If a genuine dual-contract is ever wanted, it needs `ace_generator` to emit multiple definitions per method + `semantic_analyzer` to hold a *set* of forced types - explicitly out of scope here.
2. **Lifter atomicity.** `ace_lifter._parse_annotations` rejects the whole block on any unknown directive (`else: return {}`). `@ace_condition`/`@ace_expression` (§1.2) and the SignalRow trigger directives (§4) must be taught to the lifter in the **same commit** as the codegen that emits them, or every regenerate breaks lift.
3. **Paren-aware param parsing.** Default values contain commas (`Vector2(0, 0)`); split the param list only at depth-0 commas, then split each param on the first depth-0 ` = ` (§1.3).
4. **Defaults are raw expression strings, emitted verbatim** - never through `_to_code_literal` (no vector case). (§1.3)
5. **Duplicate-`ace_id` guard does not exist** (`ace_registry._ensure_builtin_cache:18-22` silently overwrites the index, keeping both copies in the cache → double picker entries). The ~16 new ids here make this load-bearing: **add an explicit duplicate-id assertion** (in `builtin_ace_compile_test` or a `push_error` in `_ensure_builtin_cache`). (§8 step 1)
6. **Autoload carve-out for `{host.}`** - `host_default=""` in autoload/plain-node mode; only `behavior_mode` supplies `"host"`. (§2.1)
7. **Condition host-targeting is net-new plumbing** - new `generate_condition` param + call-site change + `{host.}`-before-negation. (§2.1)
8. **Per-frame ordering is not enforced by the engine.** The §7 AFTER relies on `ApplyGravity` running before `MoveAndSlide` and rows compiling in author order. Add a test asserting "gravity before move_and_slide" for the movement-skeleton starter output, and document the canonical order in the L1 starter so a user reordering rows is the only way to break it.

---

## 10. Files to touch

| File | Change |
|---|---|
| `addons/eventforge/compiler/action_codegen.gd` | Add `host_default` param to `generate_action` (mirror `target_default` `:10-41`); resolve `{host.}` via the regex engine `:54-78`. |
| `addons/eventforge/compiler/condition_codegen.gd` | **Net-new:** add `host_default` param to `generate_condition` (`:8-27`); resolve `{host.}` **before** the negation wrap `:25`. |
| `addons/eventforge/compiler/sheet_compiler.gd` | Thread `host_default="host"` into action/condition codegen **only when `behavior_mode`** (`""` for autoload/plain). Three-way `_emit_expose_annotations` (`:1215-1247`): `TYPE_NIL`→action, `TYPE_BOOL`→condition, else→expression. Emit param defaults verbatim in `_emit_function_params` (`:1259-1278`); warn on defaulted-before-required. SignalRow trigger annotations in `_emit_signal_line` (`:1385-1394`). |
| `addons/eventforge/registration/modules/core_aces.gd` | Retrofit `MoveAndSlide`/`SetVelocity2D`/`IsOnFloor` to `{host.}`. Add Movement actions `SetVelocityX/Y`, `AddVelocity`, `ApplyGravity`/`ApplyGravitySimple`, `AccelerateVelocityX/Y` and expressions `GetVelocityX/Y` (§2.2). |
| `addons/eventforge/registration/modules/collision_aces.gd` | Retrofit `IsOnWall`/`IsOnCeiling`/`GetWallNormal`/`GetFloorNormal` (`:19-22`) + 3D twins (`:45-48`) to `{host.}`. |
| `addons/eventforge/registration/modules/collection_aces.gd` | Add `SetLocalFromAxis` action (the missing `GetInputAxis` consumer, `:60`). |
| `addons/eventforge/registration/modules/helper_aces.gd` | Add `SetLocalVarTyped` alongside `SetLocalVar` (`:50`). |
| `addons/eventforge/registration/modules/native_3d_aces.gd` | CharacterBody3D/Vector3 twins of the velocity/gravity/accelerate ACEs. |
| `addons/eventforge/registration/ace_registry.gd` | Add duplicate-`ace_id` guard in `_ensure_builtin_cache` (`:18-22`). |
| `addons/eventforge/resources/signal_row.gd` | Add `trigger`/`ace_name`/`ace_category` fields (§4). |
| `addons/eventsheet/editor/function_dialog.gd` | Per-param default control in `add_param_row` (`:115-133`); return `{id,type_name,default}` from `collect_params` (`:145-156`); validate trailing-default ordering. |
| `addons/eventsheet/editor/event_sheet_dock.gd` | Copy `default` into `ACEParam.default_value` (~`:6362`). Synthetic Functions picker category (§1.5). "Add movement skeleton" starter action (§6). Pre-fill `ReturnValue.{value}` from the editing function's return type (§1.4). |
| `addons/eventsheet/editor/variable_dialog.gd` | Surface the `exported` toggle as "Internal (not shown in Inspector)" (§3 Tier 2). |
| `addons/eventforge/importer/function_parser.gd` | Paren-aware parse of `id: Type = default` in `_parse_header` (`:56-60`). |
| `addons/eventforge/importer/ace_lifter.gd` | Recognise `@ace_condition`/`@ace_expression` + SignalRow trigger directives in `_parse_annotations` (`:194-218`); capture param defaults in `_lift_sheet_function` (`:238-246`). **Atomic with the codegen change.** |
| `tools/pack_builders/flash.gd` | Re-author as zero RawCode (§5.1) - first proof. |
| `tools/pack_builders/platformer.gd` | Convert `jump()`/`jump_released()` + gravity/input/accel tick slice (§5.2/§7); keep numeric remainder as RawCode with a documented budget reason. |
| `tools/pack_builders/abilities.gd`, `health.gd` | Re-author getters as EventFunctions; verify byte-identical annotations (§5.2). |
| `tools/project_doctor.gd` | Non-blocking `RawCodeInBundledPack` advisory (§5.3). |

## 11. Tests to add

- `host_target_codegen_test.gd` - behaviour-mode sheet compiles `host.move_and_slide()` / `host.velocity.x = …`; the SAME ACEs on a plain CharacterBody2D sheet compile bare; an **autoload** sheet compiles bare.
- `physics_aces_test.gd` - templates for `SetVelocityX/Y`, `AddVelocity`, `ApplyGravity` (incl. `minf` clamp), `AccelerateVelocityX/Y`, `GetVelocityX/Y`, 3D twins; `SetLocalFromAxis` + `SetLocalVarTyped` emit typed locals.
- `function_defaults_test.gd` - `[amount:int=10, crit:bool=false]` emits the typed default header; a `Vector2(0,0)` default survives codegen verbatim; defaulted-before-required raises the ordering warning.
- `function_expose_type_test.gd` - void→`@ace_action` only (byte-identical to today), bool→`@ace_condition`, value→`@ace_expression`. Extends `sheet_function_test.gd`.
- `function_default_roundtrip_test.gd` - compile a function with a `Vector2` param default, lift via `ace_lifter`/`function_parser`, recompile, assert byte-identical (paren-aware split holds; `@ace_expression` survives).
- `signal_trigger_row_test.gd` - an annotated `SignalRow` emits `## @ace_trigger`/`@ace_name`/`@ace_category` + `signal …` and lifts back byte-stable.
- `flash_pack_zero_rawcode_test.gd` - re-authored `flash` has zero `RawCodeRow`; compiled `.gd` is behaviourally equivalent to the prior golden.
- `pack_rawcode_budget_test.gd` - per-pack `{pack: max_rawcode_rows}` ratchet; fails if any pack EXCEEDS its budget (`flash`=0); documented non-zero budgets allowed for numeric packs.
- `functions_picker_category_test.gd` - building a `CallFunction` via the Functions category binds `function_name` + positional typed fields and compiles identically to the manual free-text path.
- `movement_skeleton_starter_test.gd` - "Add movement skeleton" inserts the canonical `ApplyGravity→SetLocalFromAxis→AccelerateVelocityX→MoveAndSlide` chain, host-targeted, compiling cleanly; asserts gravity precedes move_and_slide.
- `duplicate_ace_id_test.gd` - registering two descriptors with the same `provider::ace_id` fails loudly.

## 12. Open questions (genuine decisions before/while building)

1. **Staging:** ship vocabulary + host-targeting + `flash` proof first, convert remaining packs incrementally under the ratchet (recommended) - or convert everything in one release (larger golden churn)?
2. **Host-targeting retrofit scope:** adopt `{host.}` for ALL node-scoped Core/collision ACEs at once (uniform, larger diff) or only the movement set the platformer needs first?
3. **`ApplyGravity` default:** literal `980.0` (transparent) vs `ProjectSettings` default gravity (correct)? Recommendation: literal + a separate `GetDefaultGravity` expression.
4. **Param-default widget fidelity:** a single raw-expression `LineEdit` per default (simplest, consistent) vs type-specific widgets matching the variable dialog?
5. **Budget policy this release:** hard-commit `flash`=0 (contingent on §4) now, defer the rest - confirm.
