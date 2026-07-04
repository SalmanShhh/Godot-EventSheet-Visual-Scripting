# Spec - Near-zero-annotation custom addons (`@ace_expose_all`)

**Status:** proposed (workflow-designed + adversarially reviewed: verdict *minor-fixes*) · **Date:** 2026-06-23

**Motivation (user):** *"make it easier to make custom addons without having to be super verbose too! it needs to be easy to integrate into pre-existing projects, big or small!"*

---

## 1. The problem (quantified)

`eventsheet_addons/weapon_kit/weapon_kit_behavior.gd` is **235 lines, 83 of them `## @ace_*` directives (~35%)**. A typical member carries **4 annotation lines over 1 line of code**:

```gdscript
## @ace_condition
## @ace_name("Can Fire")
## @ace_category("Weapon")
## @ace_codegen_template("$WeaponKit.can_fire()")
func can_fire() -> bool:
    return not _reloading and _cooldown <= 0.0 and current_ammo > 0 and _burst_left <= 0
```

## 2. What already works (verified ground truth)

For **methods and signals**, the analyzer already registers every own-declared member **with zero annotations** - `parse_source_metadata` keys a member on its declaration line regardless of preceding `##` directives. Proof: `tests/fixtures/auto_ace_sample.gd:18` `func is_dead() -> bool` has **zero** annotations, yet `tests/auto_ace_system_test.gd` asserts `method:is_dead` is found and classified `CONDITION`.

- **Type** is inferred from return type - `ace_generator._resolve_method_ace_type:262-270` (`bool→CONDITION`, `void→ACTION`, value→`EXPRESSION`, `signal→TRIGGER`).
- **Name** is humanized - `semantic_analyzer.build_method_display_name` (`can_fire → "Can Fire"`).
- **Codegen** is synthesized at apply-time - `event_sheet_dock._baked_template_for:2629` emits an **instance-backed** call `__eventsheet_provider_<Class>.<method>({args})`; the compiler (`addons/eventforge/compiler/sheet_compiler.gd:541-571`) declares each provider once as `var __eventsheet_provider_Class := Class.new()`.

**So `@ace_condition`, `@ace_name`, and (for a `RefCounted` helper) `@ace_codegen_template` are already redundant.** The genuinely load-bearing annotation in `can_fire` is only `@ace_codegen_template("$WeaponKit.can_fire()")` - it exists *solely* to get the **node-targeted** form (`$WeaponKit…`) instead of the instance-backed one, because Weapon Kit is a stateful Node, not an owned `RefCounted`.

## 3. The opt-in - one class-level line

```gdscript
## @ace_expose_all          # instance-backed: a RefCounted helper the sheet owns
## @ace_expose_all(node)    # node-targeted: a behavior/Node on a specific node
```

- Flips the provider's exposure from "members with a parsed override" to **all of the script's OWN public members** (`get_script_method_list()` / `get_script_signal_list()` - own, not inherited; skip `_`-prefixed + `COMMON_METHOD_IGNORE`).
- `(node)` mode: for each method lacking an explicit template, synthesize `metadata.codegen_template = "$<Provider>.<method>({args})"` **before** `_apply_template_overrides`, so the existing `_parameterize_node_target` turns it into the `{target}` "On node" param (defaulting to `$<Provider>`) - the Construct "acts on the instance you picked" model. **This is the verbosity-killer**: it removes every per-method `@ace_codegen_template`.
- Per-member `## @ace_*` annotations remain available as **optional overrides** (custom name, category, description, enum dropdown, forced type, `## @ace_hidden`).
- **One class → one category:** when `infer_category` falls back to `"Gameplay"`, substitute the provider's class name, so a cohesive addon collapses into one tidy picker group (like a C3 behavior's ACE group).

## 4. Review corrections (folded in - do NOT skip)

1. **[high] No "byte-identical migration" claim.** Some Weapon Kit values genuinely differ from reflection: `emptied`→humanizes to "On Emptied" (annotated "On Empty"), `reload_completed`→"On Reload Completed" (annotated "On Reload Complete"), `set_max_ammo`→"Set Max Ammo" (annotated "Set Magazine Size"); and `@ace_category("Weapon")` is not in the keyword table. **Expose-all removes only the *redundant* annotations** (codegen matching the synthesized form, type markers matching the return type, name lines matching the humanized identifier). Genuinely-different names/categories STAY as overrides. The migration test is a **characterization** diff, not a zero-residual assertion.
2. **[high] Property codegen gap - do not widen it.** ~~Reflected property `Set`/`Add`/`Subtract` (`source_kind=property_action`) have **no** codegen template, and `_baked_template_for` only bakes `source_kind==method`, so they compile to **empty** output (a silent no-op - covenant violation).~~ **DELIVERED 2026-07-04**: the generator now synthesizes property templates at generation time - Node providers get the retargetable node form (`{target}.prop = {value}` via `_parameterize_node_target`), utility providers the owned-instance form; the read expression carries real code too. Pinned by `tests/expose_all_properties_test.gd`.
3. **[medium] `get_script_property_list()` is not clean** (includes a spurious `*.gd` entry; `gdscript_lint.gd:108-110` filters it). Empirically dump usage flags in 4.7 before relaxing the property gate - part of the deferred property work.
4. **[medium] Autoload id mismatch** - ~~`get_provider_id` `capitalize()` ("Weapon Kit") vs `_autoload_provider_names` `to_pascal_case()` ("WeaponKit").~~ **RECONCILED 2026-07-04**: the map fallback now uses `capitalize()` to match `get_provider_id`, so trigger baking finds class_name-less autoloads. The singleton-prefix node-form (actions calling the singleton by name) remains deferred.
5. **[low] Drop the bare `@ace` alias** - `semantic_analyzer.gd:35/46` match `begins_with("@ace_")` (trailing underscore), so a bare `## @ace` leaks into the doc string. Use **`@ace_expose_all` only**.
6. **[low] Citations:** live registry = `addons/eventsheet/ace/ace_registry.gd`; compiler = `addons/eventforge/compiler/sheet_compiler.gd`; `get_script_property_list` precedent = `gdscript_lint.gd:108`.
7. **Missing case - duplicate picker rows:** `_store_definition` appends to a flat `_definitions` array with no dedup, so same-`class_name` providers double-list. Expose-all widens each surface; note the risk.

## 5. MVP scope (build first, safe + verifiable)

**In:** `## @ace_expose_all` + `## @ace_expose_all(node)` for **methods + signals**; own-member lists; the `(node)` node-form template synthesis; the class-name category default; per-member overrides + `@ace_hidden`; tests + a fixture; a characterization migration of one pack.
**Deferred (documented follow-ups):** ~~property-write codegen (the covenant gap)~~ DELIVERED 2026-07-04 (see review note 2); plain-`var` (non-@export) exposure; autoload singleton-prefix node-form; the instance-backed **codegen preview** blank for METHODS (property ACEs now show real templates; method preview reads `metadata.codegen_template`, still empty for instance-backed methods); non-primitive-signature method handling.

## 6. Files to touch

- `addons/eventsheet/ace/semantic_analyzer.gd` - parse the class-level `## @ace_expose_all` (+ optional `(node)` modifier) into `metadata.expose_all` / `metadata.expose_all_mode`.
- `addons/eventsheet/ace/ace_generator.gd` - when `expose_all`: iterate `get_script_method_list()` / `get_script_signal_list()` and expose all (skip `_` + `COMMON_METHOD_IGNORE`), no override gate; for `(node)` mode synthesize `$<Provider>.<method>({args})` before `_apply_template_overrides`; thread `provider_id` as the category fallback.
- `tools/pack_builders/weapon_kit.gd` (+ regenerate `eventsheet_addons/weapon_kit/weapon_kit_behavior.gd`) - characterization migration: `## @ace_expose_all(node)` at class level, drop the redundant per-member lines, keep the genuinely-different overrides.
- `docs/CUSTOM-ACES-GUIDE.md` + `docs/USING-WITH-EXISTING-CODE.md` - document the one-line opt-in + the instance-backed-vs-node decision + how a pre-existing class registers (per-sheet `add_ace_provider_script`, `eventsheet_addons/` folder, annotated autoload - all already work).

## 7. Tests to add

- `expose_all_test.gd` - a `RefCounted` fixture with `## @ace_expose_all` + zero per-member annotations: every own public method/signal publishes + classifies correctly; inherited (`RefCounted.reference`) + `_`-prefixed members do NOT.
- `expose_all_node_mode_test.gd` - a Node fixture with `## @ace_expose_all(node)`: a method's baked template is `{target}.method({args})` with an "On node" param defaulting to `$Class` (went through `_parameterize_node_target`), not the instance-backed form.
- `expose_all_hidden_test.gd` - `## @ace_hidden` removes exactly one member; methods+signals only (no property actions surfaced under MVP).
- `weapon_kit_characterization_test.gd` - diff the pre/post ACE set; assert the residual override lines are exactly the genuinely-different ones (names/categories), drift on generated code = 0.

## 8. Integration (pre-existing projects)

Three registration surfaces already exist and need no change (`@ace_expose_all` is just another line they read): per-sheet `add_ace_provider_script("res://…")` (recommended for adopting an existing class in place), the `res://eventsheet_addons/` folder scan, and an annotated **autoload** (the `^\s*## @ace_` gate already matches `## @ace_expose_all`). **No project-wide auto-scan** - per-source opt-in is the noise gate, so a big project never floods the picker.
