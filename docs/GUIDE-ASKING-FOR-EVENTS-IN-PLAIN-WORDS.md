# Ask - Saying What You Want and Getting Events Back

**View ▸ Ask…** lets you type what you want to happen in ordinary words and read back a proposal
made of ordinary event rows. It is off until you turn it on, it asks a service you choose, and it
never changes your sheet without a second click.

If you would rather your project never talk to anything outside your machine, leave Ask off. It is
off by default and everything else in the plugin works exactly the same without it.

## What is sent, exactly

This is the whole list. Nothing else leaves the machine, and none of it leaves until you press
**Ask**:

1. **The sentence you typed.** Just that sentence.
2. **This sheet's object census** - the names the sheet's rows use for its objects, and what type
   each one is. For example `Player (CharacterBody2D)`.
3. **The vocabulary this sheet can write** - one line per condition and action in the picker: its
   id, whether it is a trigger, a condition or an action, the words it shows, and the parameters
   it takes. This is the same list the picker offers you.

What is **not** sent: your rows, your code, your file paths, your project name, your scenes, your
variables' values, anything about your machine, and anything at all when Ask is off. There is no
background call and no usage reporting. The request is built in one function
(`EventSheetAsk.build_request`) and the test suite pins its entire contents, so this page cannot
drift away from the truth without the suite noticing.

## What can come back

Ask does not accept code. It asks for a list of rows in one fixed shape:

```json
{"rows": [{"object": "Player", "ace_id": "Core::Jump", "params": {"height": "400"}}]}
```

Every row is then checked against your project's own vocabulary before you see it:

- an `ace_id` your project does not have is **dropped**, and the box tells you which one and why;
- a parameter the entry does not declare is **dropped** too, and named;
- an answer that is not a list of rows proposes nothing at all, and says so.

So the worst a bad answer can do is propose fewer rows than it meant to. It cannot propose
something your sheet has no words for, and it cannot hand you a block of code to trust.

<img src="images/ask-box-proposal.png" alt="The Ask box: a line saying Ask is on with a local model and naming the endpoint it will reach, the typed sentence 'when the player presses jump and is on the floor, jump and play the jump sound', and a Proposed panel listing a condition row and two action rows followed by one entry dropped because this project has no such vocabulary. Three buttons across the bottom: Ask, Add these events, Discard." width="620">

## The two buttons

Nothing is applied by arriving. The proposal sits in the box until you choose:

- **Add these events** - the rows are added to the sheet you asked from, through the ordinary undo
  funnel. Ctrl+Z takes them back out.
- **Discard** - the proposal and the sentence are cleared.

## Turning it on

Everything lives in **Project Settings ▸ EventSheets ▸ Ask**:

| Setting | What it is |
| --- | --- |
| `mode` | `off` (the default), `your own key`, or `a local model`. |
| `endpoint` | An HTTP endpoint that speaks the common chat format. Yours to choose - a hosted one, or one running on this machine. |
| `model` | The model name that endpoint expects. |
| `api_key` | Your own key for that endpoint, when it wants one. A local endpoint usually does not. |

Pressing **Ask** makes one HTTP POST to that endpoint, carrying the request described above and
your key as a bearer header when you gave one. That call is the only socket this plugin ever opens,
and it is only ever reached from that button.

Two things to know:

- **A mode with no endpoint is still off.** There is nothing to send to, so Ask refuses rather than
  failing at the worst moment.
- **A word the plugin does not recognise in `mode` reads as off.** A typo in `project.godot` can
  never switch Ask on by accident.

The plugin names no vendor and prefers none: any endpoint that speaks the common chat format works,
including one running entirely on your own machine, which is the setting to choose if you want the
convenience without anything leaving the building.

## Why it is shaped this way

A beginner's shortest road from "I want the player to jump when they press jump and are on the
floor" to rows they can read should not go through a wall of generated code they cannot check. So
Ask never produces code: it produces rows, in your project's own vocabulary, checked against your
project's own registry, shown to you first. Whatever it proposes, you can read - and if you cannot
read it, it does not go in.
