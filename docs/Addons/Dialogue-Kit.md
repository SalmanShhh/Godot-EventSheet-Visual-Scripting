# Dialogue Kit

**Dialogue Kit** is a per-node `DialogueKitBehavior` you attach to a UI node that holds your dialogue box.
It runs typewriter conversations: you queue up lines (a speaker and their text), start the dialogue, and
it types each line out character by character into named labels, waiting for the player to advance. It
finds your UI by name (a panel, a speaker label, and a text label), so there is nothing to wire by hand,
and it fires triggers as each line and the whole conversation start and finish.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Story cutscenes** - a line-by-line conversation between characters.
- **NPC chatter** - talk to a villager and read what they say.
- **Tutorial prompts** - a guide character explains the controls.
- **Item and lore descriptions** typed out one line at a time.
- **Boss taunts** before a fight.
- **Visual-novel style scenes** with alternating speakers.
- **Sign and note reading** in an adventure game.
- **Radio or comms chatter** during a mission.
- **Quest hand-ins** where an NPC reacts across several lines.
- **Intro narration** that types over a title screen.

## Core concepts

- **Queue, then start.** You **Queue Line** for each line of a conversation (a speaker name and the
  text), then **Start Dialogue** to begin. The kit shows the panel and types the first line.
- **Typewriter typing.** Text appears character by character at Chars Per Second. While it is still
  typing, **Advance** finishes the current line instantly; once a line is fully shown, **Advance** moves
  to the next line.
- **It drives named UI.** The kit looks under the node it is attached to for a panel, a speaker label,
  and a text label by the names you set in the Inspector, and writes into them. You build the look; the
  kit fills in the words.
- **Triggers frame the flow.** On Dialogue Started / Finished bracket the whole conversation; On Line
  Started / Finished fire per line, so you can play a blip, change a portrait, or shake on emphasis.
- **Advance on a button.** The Advance Action (an input action name) is what the player presses; you can
  also call Advance yourself.

## Setup

Build a dialogue box: a panel (named `DialoguePanel` by default) containing a `SpeakerLabel` and a
`TextLabel`. Attach a **Dialogue Kit** behavior to the node that contains them (or its parent). Then queue
lines and start.

```
On talk to NPC
  -> NPC Dialogue | Dialogue Kit: Queue Line  "Elder", "Welcome, traveler."
  -> NPC Dialogue | Dialogue Kit: Queue Line  "Elder", "The bridge to the north has fallen."
  -> NPC Dialogue | Dialogue Kit: Start Dialogue
```

The player presses the Advance Action (ui_accept by default) to move through the lines.

## ACE reference

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Queue Line | speaker, text | Adds a line (a speaker and their text) to the conversation queue. |
| Start Dialogue | (none) | Shows the panel and begins typing the first queued line. |
| Advance | (none) | Finishes the current line if it is still typing, otherwise moves to the next line. |
| End Dialogue | (none) | Ends the conversation and hides the panel. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Is Dialogue Active | (none) | Whether a conversation is currently running. |
| Is Typing | (none) | Whether the current line is still typing out. |
| Speaker Is | speaker | Whether the current line's speaker matches a name. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Current Speaker | String | The speaker of the current line. |
| Current Text | String | The text of the current line. |
| Lines Remaining | number | How many lines are still queued after the current one. |

### Triggers

| Trigger | Description |
|---------|-------------|
| On Dialogue Started | Fires when Start Dialogue begins a conversation. |
| On Dialogue Finished | Fires when the last line is done (or End Dialogue is called). |
| On Line Started | Fires when a new line begins typing. |
| On Line Finished | Fires when a line has finished typing. |

### Inspector properties

| Property | Default | Description |
|----------|---------|-------------|
| Advance Action | "ui_accept" | The input action the player presses to advance a line. |
| Chars Per Second | 40.0 | Typewriter speed, in characters per second. |
| Panel Name | "DialoguePanel" | The name of the panel node to show and hide. |
| Speaker Label Name | "SpeakerLabel" | The name of the label that shows the speaker. |
| Text Label Name | "TextLabel" | The name of the label the text types into. |

## Use cases

**1. A simple NPC chat.**

```
On interact with Elder
  -> Dialogue Kit: Queue Line  "Elder", "Hello there."
  -> Dialogue Kit: Queue Line  "Elder", "Safe travels."
  -> Dialogue Kit: Start Dialogue
```

**2. Two speakers taking turns.**

```
  -> Queue Line  "Hero", "Who goes there?"
  -> Queue Line  "Guard", "None of your concern."
  -> Start Dialogue
```

**3. Freeze the player during dialogue.**

```
On Dialogue Started
  -> disable player movement
On Dialogue Finished
  -> enable player movement
```

**4. Type blip per character (via line start).**

```
On Line Started
  -> play a soft "blip" sound
```

**5. Swap the portrait to the speaker.**

```
On Line Started
  Condition: Dialogue Kit  Speaker Is  "Elder"
    -> set Portrait to the elder image
```

**6. Show a "press to continue" arrow only when a line is done.**

```
Every tick
  -> set ContinueArrow visible = not Dialogue Kit.Is Typing() and Dialogue Kit.Is Dialogue Active()
```

**7. Skip typing on a button.** The Advance Action already does this: pressing it while typing finishes
the line instantly.

**8. Branch after a conversation.**

```
On Dialogue Finished
  Condition: quest "bridge" not started
    -> start the quest
```

**9. Give an NPC a longer, slower speech.** Lower Chars Per Second in the Inspector for a solemn speaker.

**10. Show how much is left.**

```
Every tick
  -> set ProgressLabel text = Dialogue Kit.Lines Remaining() + " lines left"
```

**11. End a conversation early.**

```
On escape pressed
  Condition: Dialogue Kit  Is Dialogue Active
    -> Dialogue Kit: End Dialogue
```

**12. React to the current text (for voice or effects).**

```
On Line Started
  -> look up a voice clip by Dialogue Kit.Current Speaker() and play it
```

**13. Auto-advancing cutscene.** An intro scene that plays itself: advance on a timer, but only once the
current line has finished typing.

```
Every 2 seconds
  Condition: Dialogue Kit  Is Dialogue Active
  Condition: Dialogue Kit  Is Typing  (inverted)
    -> Dialogue Kit: Advance
```

Keep the interval a little longer than your slowest line takes to read.

**14. Portraits that ease in with Fade.** Pair with the Fade pack so each speaker's portrait fades in
instead of popping when their line starts.

```
On Line Started
  Condition: Dialogue Kit  Speaker Is  "Guard"
    -> GuardPortrait | Fade: Fade In  0.2
```

**15. Clean up when gameplay interrupts a conversation.** If the player dies or the level ends mid-line,
end the dialogue so the panel is not stuck on screen after the restart.

```
On player died
  Condition: Dialogue Kit  Is Dialogue Active
    -> Dialogue Kit: End Dialogue
  -> restart the level
```

### Other use cases

**Shopkeeper greetings.** Queue a one-line welcome when the player opens a shop, so every merchant has a voice without a full cutscene system.

**Loading-screen lore.** Type a short piece of world lore onto the loading screen and let On Dialogue Finished tell you the player has read it before the level swaps in.

**Boss phase taunts.** At each boss health threshold, queue a taunt line and start it; freeze the arena on On Dialogue Started for a dramatic beat.

**Tutorial coach.** A guide character queues a hint line whenever the player reaches a new mechanic, using Lines Remaining to keep a progress dot row in sync.

**Typed credits.** Queue the credits as speaker and role pairs and let the typewriter pace the crawl, ending on On Dialogue Finished to return to the menu.

## Tips and common mistakes

- **Name your UI to match** the Panel / Speaker Label / Text Label names, or set the names in the
  Inspector to match your nodes - the kit finds them by name.
- **Queue all the lines, then Start** - queuing after Start still works, but the natural flow is to build
  the conversation first.
- **Advance does double duty**: it finishes typing first, then moves on, so one button both skips and
  continues.
- **Freeze gameplay on On Dialogue Started** and restore it on On Dialogue Finished so the player cannot
  walk off mid-line.
- **Chars Per Second sets the pace** - fast for chatter, slow for drama.
- **Speaker Is is handy for portraits and voices** - branch on who is talking in On Line Started.
- **End Dialogue hides the panel** and stops the conversation; use it for a skip button.
