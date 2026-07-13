# Using the ACE Studio to Author a Verb

In an event sheet, a **verb** is a reusable function you define once and call anywhere. The ACE Studio is the in-editor dialog that lets you author one of these verbs without ever meeting the words `func` or `return type`, while still producing plain, readable GDScript underneath. Its full title is **"Define a Verb"**, and it turns the low-level idea of "add a function" into plain-language cards, a live preview of how your verb will look to other people, and an honest **"Ships as"** line that shows the exact GDScript signature your verb generates.

The word **ACE** is the plugin's name for the three things a sheet's picker can offer you: an **Action** (does something), a **Condition** (a yes/no test), and an **Expression** (returns a value). The ACE Studio lets you write any one of these as a verb, and optionally **publish** it so that every other sheet in your project can pick it. Everything you build here compiles to a plain GDScript function - the ACE Studio is a friendly front end, not a runtime layer that sits under your game.

![The ACE Studio: three verb-kind cards (Does something / Is it true? / A value), a live picker preview of the published verb, and the GDScript signature it ships as](images/ace-studio.png)

## Table of Contents

1. [Opening the ACE Studio](#1-opening-the-ace-studio)
2. [Choosing What Kind of Verb](#2-choosing-what-kind-of-verb)
3. [The Live Preview and the Ships-as Line](#3-the-live-preview-and-the-ships-as-line)
4. [Adding Parameters](#4-adding-parameters)
5. [Run Only When: Guard Conditions](#5-run-only-when-guard-conditions)
6. [Publishing to the Picker](#6-publishing-to-the-picker)
7. [After You Create the Verb](#7-after-you-create-the-verb)
8. [Use Cases](#8-use-cases)
9. [Tips and Common Mistakes](#9-tips-and-common-mistakes)

---

## 1. Opening the ACE Studio

There are three ways to open the ACE Studio to author a brand-new verb:

- The **Add** menu in the event sheet dock has a **"Function..."** entry.
- There is an **add-function button** in the sheet itself.
- It is reachable from the **Command Palette** (Ctrl+P).

All three open the same **"Define a Verb"** dialog with empty fields, ready for a new verb.

To **edit an existing verb**, double-click its **Define block** on the sheet canvas. The dialog reopens pre-filled in edit mode: its title becomes **"Edit Verb - <name>"** and the confirm button becomes **"Save Changes"** instead of "Create Function". Editing lets you rename the verb, change its kind, adjust parameters, or change how it publishes - all without touching code.

---

## 2. Choosing What Kind of Verb

The first fields you fill in describe the verb itself.

- **Name** - the verb's name, for example `Take Damage`. You can type it in plain words with spaces and capitals; the ACE Studio turns it into a valid identifier automatically, so `Take Damage` becomes `take_damage`.
- **Description** - what the verb does. This text is shown in the picker so other people (or future you) know what the verb is for.

Next comes **"What kind of verb is this?"** - three plain-language cards. Click one:

- **"Does something"** (an **Action**, its glyph is a play triangle). Examples: Take Damage, Heal, Knock Back. An Action is a setter and returns nothing.
- **"Is it true?"** (a **Condition**, its glyph is a question mark). Examples: Is Dead, Is Full Health. A Condition answers yes or no.
- **"A value"** (an **Expression**, its glyph is `fx`). Examples: Health %, Remaining Shields. An Expression is a getter and returns a value.

The card you pick quietly sets the return type behind the scenes: nothing for an Action, yes/no for a Condition, and the value type you choose for an Expression. You never have to type a return type yourself.

When - and only when - you pick **"A value"**, a second dropdown appears: **"What kind of value?"** It decides what type your Expression returns. The options are:

- **a number** (float)
- **a whole number** (int)
- **text** (String)
- **yes / no** (bool)
- **a point** (Vector2)
- **a 3D point** (Vector3)
- **anything** (Variant)

If you pick an Action or a Condition, this dropdown stays hidden, because their return types are already decided for you.

---

## 3. The Live Preview and the Ships-as Line

![A filled-in ACE Studio: a Take Damage action with an amount parameter, the live preview showing the Action badge and param chip, the Ships-as line reading func take_damage(amount: float) -> void, a host.enabled guard, and the publish card set to the Combat category](images/ace-studio-example.png)

The card labelled **"This is what other people will see"** is a live preview that updates on every keystroke. It is there so you can shape a clear, picker-ready verb before you commit. It shows:

- A mock picker entry with a **role badge** (Action, Condition, or Expression), the **display name**, a **chip for each parameter**, and a **category chip**.
- A one-line summary that reads like a real picker row, for example `Combat > Take Damage  amount`.
- A **"SHIPS AS"** line showing the exact generated signature, for example `func take_damage(amount: float) -> void`.

The "Ships as" line is built from the compiler's own formatters - the same code that emits your final GDScript. That means the signature in the preview can never disagree with the code that actually ships. It is the honest bridge for anyone who wants to see the real function that will be generated, and it is the fastest way to hand a verb to a programmer teammate: they can read exactly what the call will look like in code.

---

## 4. Adding Parameters

Parameters are the values a verb takes in - the `amount` in Take Damage, or the direction and force in Knock Back.

The **Parameters** card has a **"+ Add parameter"** button. Each time you click it, a row appears with four fields:

- **Name** - the parameter's name, for example `amount`.
- **Type** - a dropdown: float, int, bool, String, Vector2, Vector3, or Variant.
- **Default value** (optional) - a GDScript expression used when the caller does not supply the value, for example `10.0` or `Vector2.ZERO`.
- **Description** - a short note about what the parameter is for.

A **remove button** clears a row you no longer want.

One rule to remember: **parameters that have a default value must come after those that do not.** This mirrors how GDScript itself works - once one parameter has a default, every parameter after it needs one too. If you order them the other way around, the dialog refuses to confirm and shows a short problem message explaining what to fix.

---

## 5. Run Only When: Guard Conditions

The **"Run only when"** card lets you gate the verb so its body only runs in the right situation. It has a **"+ Add condition"** button; each click adds a guard row.

Each guard is a **GDScript boolean expression**, for example `host.enabled` or `is_active`. The verb's body runs only when **every** guard is true. If any guard is false, the verb simply does nothing that call.

This card is shown only when you are creating a new verb. It is **hidden when you are editing an existing verb**, because by that point the guards already live in the verb's body as condition rows wrapping the logic - you edit them there on the canvas rather than in the dialog.

---

## 6. Publishing to the Picker

By default a verb is a private helper for the sheet you are on. To make it reusable across your whole project, tick the checkbox **"Publish to the picker (other sheets can use it)"**.

Ticking it reveals two more fields:

- **Display name** - the friendly name shown in the picker. It defaults from the verb's name, but you can polish it.
- **Picker category** - the section the verb is filed under in the picker, for example `Combat`.

Once published, the verb appears in **every** sheet's picker as the kind you chose - an Action, a Condition, or an Expression - exactly as the live preview showed it. Publishing is how a verb graduates from a one-sheet helper into shared project vocabulary that your whole team can reach for.

Only publish the verbs you actually mean to reuse. A verb that is only useful inside one sheet is better left unpublished, so the picker stays clean and full of genuinely reusable choices.

---

## 7. After You Create the Verb

When you press **"Create Function"** (or **"Save Changes"** in edit mode), a few things happen:

- The verb appears among the sheet's functions as a **Define block**. You author its **body** as ordinary event rows underneath the block - the same conditions and actions you use anywhere else. Any **"Run only when"** guards you added become condition rows wrapping that body.
- You call the verb from anywhere with the **Call Function** action.
- If you published it, it shows up in **every sheet's picker** as an Action, Condition, or Expression, matching the preview.
- Everything compiles to a **plain GDScript function**. The ACE Studio is a friendly front end, not a hidden runtime; the "Ships as" line is the bridge for a programmer who wants to see the real signature.

Before the dialog will confirm, it checks a few things. The **name must be a valid identifier** and must **not collide** with an existing function or variable on the sheet, and **parameters with defaults must be trailing**. When something is wrong, the dialog shows a short problem message and stays open so you can fix it.

This no-code path complements two other ways to add vocabulary. The **"Make a behaviour without code"** guide covers building a whole reusable behaviour out of rows, and the **"Custom ACEs"** guide covers the code-first annotation and registrar route for a pack author. For naming and picker craft, see the **"Designing user-friendly ACEs"** guide.

---

## 8. Use Cases

1. **A Take Damage action shared across enemies.** Author a `Take Damage` verb as an Action with an `amount` parameter, publish it under Combat, and every enemy sheet can pick it. One definition, consistent damage handling everywhere.

2. **An Is Dead condition read from many sheets.** Author `Is Dead` as a Condition (the "Is it true?" card) that checks whether health has reached zero. Publish it, and any sheet - the enemy, the HUD, the score system - can test `Is Dead` without duplicating the check.

3. **A Health % expression for a HUD bar.** Pick the "A value" card and choose **a number** (float). The verb returns current health divided by max health, times one hundred. A HUD sheet reads `Health %` straight into a progress bar's value.

4. **A guarded verb that only runs while a behaviour is enabled.** Add a guard `host.enabled` in the "Run only when" card. The verb's body runs only when the host is switched on, so a disabled behaviour quietly does nothing instead of misfiring.

5. **A Knock Back action with a direction and force.** Author `Knock Back` as an Action with two parameters: `direction` of type Vector2 and `force` of type float. Publish it under Combat so every physics-driven enemy can be knocked back the same way.

6. **A project-wide Give Currency verb.** Author `Give Currency` as an Action with an `amount` parameter and publish it under an Economy category. Shops, quest rewards, and pickups all call the same verb, so the rule for granting currency lives in exactly one place.

7. **A getter that returns a spawn point.** Pick "A value" and choose **a point** (Vector2). The verb computes and returns a spawn position. A spawner sheet reads it as an Expression wherever it needs a fresh spawn location.

8. **Editing an existing verb by double-clicking its Define block.** You shipped `Take Damage` last week and now want it to also play a hurt sound. Double-click its Define block, the dialog reopens as "Edit Verb - Take Damage", adjust the parameters or publishing, press "Save Changes", then extend the body rows.

9. **A Condition that keeps a designer out of GDScript.** A designer needs an `Is Full Health` test but does not write code. They pick the "Is it true?" card, describe it, and the ACE Studio produces a real boolean function without them ever typing `func` or `return`.

10. **Checking the Ships-as line to hand a verb to a programmer.** Before asking a programmer teammate to wire something up, read the "SHIPS AS" line, for example `func take_damage(amount: float) -> void`. Because it comes from the compiler's own formatters, it is exactly the function that will be generated, so the programmer knows the precise call to make.

11. **A Remaining Shields expression for enemy AI.** Pick "A value" and choose **a whole number** (int). The verb returns how many shield charges are left. An AI sheet reads `Remaining Shields` as an Expression to decide whether to press an attack.

12. **A private helper you deliberately do not publish.** You need a small `Recompute Layout` verb used only inside one menu sheet. Leave the publish checkbox unticked so it stays a local helper and never clutters other sheets' pickers.

---

## 9. Tips and Common Mistakes

- **Defaulted parameters must be trailing.** If a parameter has a default value, every parameter after it must have one too. Put your no-default parameters first; otherwise the dialog refuses to confirm and tells you what to fix.
- **Names auto-convert to identifiers, and they can collide.** `Take Damage` becomes `take_damage` for you, but if a function or variable named `take_damage` already exists on the sheet, the dialog will stop and ask you to rename. Pick distinct names.
- **The value-type dropdown only shows for "A value".** If you do not see a "What kind of value?" dropdown, you have picked an Action or a Condition, whose return types are already decided. Only the Expression card reveals it.
- **Publish only the verbs meant to be reused.** Every published verb appears in every sheet's picker. Leave one-off helpers unpublished so the picker stays full of genuinely shared vocabulary.
- **The guards card is hidden in edit mode on purpose.** When you reopen a verb to edit it, the "Run only when" card is gone because those guards now live in the verb's body as condition rows. Edit them on the canvas, not in the dialog.
- **The Ships-as line always matches the real output.** It is generated from the same formatters the compiler uses, so trust it. If the "SHIPS AS" signature looks wrong, the fix is to change the verb's kind, name, or parameters - not to work around it in code later.
- **Write a real Description.** The description is what other people read in the picker. A one-line "what it does" saves everyone from guessing, especially for published verbs.
- **A verb is just a GDScript function.** Nothing here is magic. If you ever want to read or extend the generated code directly, it is plain, typed GDScript with the exact signature the preview showed you.
