# Interaction - "Press E To Open It", As Three Rows

Interaction is a Godot EventSheets behavior pack that gives your player the one thing every adventure, RPG, immersive sim, and farming game needs: a sense of what is close enough to touch. You attach an `InteractionBehavior` to the **player** - not to the door, not to the chest - and the player now keeps exactly one **focused interactable** at a time. **Focus Nearest Interactable** picks the closest node in a group you name, but only while it is within a reach you set in pixels. **On Focus Changed** fires the moment that pick actually changes, which is where your "Press E" label appears, moves, or disappears. **Has Focus** is the condition that gates the interact key. And **Interact With Focus** calls a plain function named `interact()` on whatever is focused, so the thing itself stays ordinary: a door is a door with an `interact()` on it, not a special object that had to be taught about your interaction system.

The split matters. The player owns "what am I near"; the thing owns "what happens when I am used". Neither has to know how the other works.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Doors, chests, levers, and switches.** The classic: walk up, a prompt appears, press the key, the thing opens. Three rows on the player and one `interact()` on the thing.
- **NPC conversations.** Focus the nearest villager, show "Talk to Mara", and let Interact With Focus hand off to a Dialogue Kit conversation.
- **Pickups you choose to take.** Not everything should be grabbed by walking over it - a focused-then-pressed pickup lets the player leave things where they are.
- **Shops, workbenches, and stations.** Any world object that opens a screen is exactly one `interact()` away.
- **Vehicles and mounts.** Focus the car, press the key, get in. The car's `interact()` owns the getting-in.
- **Readable props.** Signs, notes, gravestones, terminals - the prompt tells the player they can read it before they press anything.
- **Quest handins.** Focus a quest board or a giver, and let its `interact()` advance the quest.
- **Puzzle elements.** Pressure plates you place, valves you turn, crystals you charge - all of them just objects with an `interact()`.
- **Farming and gathering.** Focus the nearest crop or ore node inside your tool's reach and act on it with one key.
- **Co-op revives.** A downed teammate is an interactable; focus and hold to bring them back.
- **Immersive-sim style interactions.** Because the behavior only reports focus, the same key can mean loot, hack, or pry - the focused thing decides.
- **Accessibility.** One key that always acts on the thing the game says is focused is far kinder than a pile of trigger areas that fire on their own.

---

## Core concepts

**The behavior lives on the player.** One `InteractionBehavior` per player (or per anything that interacts - a companion, a robot arm). It holds a single focus, so there is no interaction id to pass around and no list to manage. If two players need their own focus, give each one its own behavior.

**Interactables are just a group.** There is no interactable class, no interface, nothing to inherit. You add your doors and chests to a group - say `interactable` - and hand that group's name to Focus Nearest Interactable. Anything in the group is a candidate; anything not in it is scenery. Adding a new kind of interactable later is one group membership, no code.

**Focus is "nearest, and within reach".** The pick is the closest group member to the host, but only if it is inside the `within` distance in pixels. Everything farther away is invisible to the pack. That distance is your reach: 48 px for a tight, deliberate game; 200 px for a forgiving one. Nothing in reach means the focus becomes nothing at all.

**Run it under a per-frame trigger.** Focus Nearest Interactable is meant to be run every tick (an On Every Tick row). It re-picks constantly because the player is constantly moving. That sounds noisy, and it would be if the trigger fired every time - which is exactly why it does not.

**On Focus Changed is an edge, not a stream.** Every focus write goes through one internal guard: if the pick is the same node it already was, nothing happens. So a per-frame Focus Nearest Interactable fires **On Focus Changed** only on real changes: nothing -> chest, chest -> door, door -> nothing. That is what makes it safe to spawn a prompt label, start a highlight, or play a sound in that trigger.

**The trigger's `node` can be nothing.** When the player walks out of reach, On Focus Changed fires with nothing. That is the signal to hide the prompt and stop the highlight, and it is why you do not need a separate "left range" hookup.

**Has Focus and Focused Node are the read side.** **Has Focus** is a condition - true while something is focused - and it is what your interact key should be gated behind. **Focused Node** is the expression that hands you the actual node, so you can read a name off it for the prompt, blink it, or compare it against something.

**Interact With Focus calls `interact()` if the thing has one.** This is the whole thing-side story. Put your door's opening logic in a plain function named `interact()` on the door, and the player's key press finds it. There is nothing to register. If you want that function to also show up in the picker as an action, annotate it - it is an ordinary function either way.

**On Interacted fires whether or not the thing has an `interact()`.** So a thing with no logic of its own is still perfectly usable: listen to **On Interacted**, check which node came through, and handle it entirely from a sheet. Use `interact()` when the behavior belongs to the object; use On Interacted when it belongs to the game.

**Clear Focus is the manual override.** Cutscenes, menus, death, and vehicles are all moments when the prompt should vanish even though the player has not moved. Clear Focus drops the focus and fires On Focus Changed with nothing, exactly like walking away would.

---

## Setup

**1. Attach the behavior to the player.** Add an `InteractionBehavior` as a child of your player node (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The host must be a `Node2D` or anything deriving from it - a `CharacterBody2D` player is the normal case, because the pack measures distance from the host's position.

**2. Put your interactables in a group.** Select each door, chest, and NPC and add them to a group - `interactable` is a good default. Make the group persistent so it survives being saved into the scene.

**3. Give each thing an `interact()`.** On the door's own script (or its own sheet), write a function named `interact()` that does the door's job. That is the entire contract.

**4. Wire the three rows.** Pick every frame, react to changes, act on the key:

```
On Every Tick
  -> Player | InteractionBehavior: Focus Nearest Interactable  "interactable", 64

On Focus Changed
  Condition: Player | InteractionBehavior  Has Focus
    -> HUD: show prompt label "Press E"
  Condition: (else)
    -> HUD: hide prompt label

On "interact" pressed
  Condition: Player | InteractionBehavior  Has Focus
    -> Player | InteractionBehavior: Interact With Focus
```

That is a complete interaction system. The prompt appears when something comes in reach, follows the player from object to object, and disappears when nothing is close. The key does nothing when nothing is focused, so there is no empty press to guard against.

**5. Make it feel alive.** Two packs finish the job: the Juice pack's **Start Blinking** on the Focused Node is the highlight, and a **HUD Kit** label is the prompt. Start both in On Focus Changed when there is a focus, stop them when there is not.

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Focus nearest **interactable** within **64** px

All rows live in the **Interaction** category and target the `InteractionBehavior` on the node they are placed on. There is no interaction id anywhere.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Focus Nearest Interactable | `group_name` (String), `within` (float) | Focuses the nearest node in `group_name` that is within `within` pixels of the host, or nothing when none are. Run it under a per-frame trigger; On Focus Changed only fires on real changes. |
| Interact With Focus | - | Calls `interact()` on the focused node if it has such a function, then fires On Interacted. Does nothing at all when nothing is focused. |
| Clear Focus | - | Drops the current focus and fires On Focus Changed with nothing - for cutscenes, menus, and death. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Focus | - | True while something interactable is focused. Gate your interact key behind it, and use it to show and hide the prompt. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Focused Node | - | Node | The node currently focused, or nothing. Feed it to Start Blinking, read a name off it for the prompt, or compare it to a specific object. |

### Triggers

| Trigger | Parameters | Fires when |
|---|---|---|
| On Focus Changed | `node` (Node) | The focused node actually changes - including to nothing when the player walks out of reach or Clear Focus runs. Never fires twice for the same pick, so it is safe under a per-frame Focus Nearest Interactable. |
| On Interacted | `node` (Node) | Interact With Focus runs with something focused. Fires whether or not the thing had an `interact()` of its own, so sheet-side handling always gets its turn. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's value expressions as ready-to-insert chains once the behaviour is attached:

- `$InteractionBehavior.focused_node()` inserts the **Focused Node** entry straight into any expression

The `$InteractionBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("InteractionBehavior")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance.

---

## Use cases

Each example assumes the behavior is on the Player and the interactables share a group.

### 1. A door that opens when you press the key

The thing owns its own behavior; the player only reports focus.

```
# On the Door (its own sheet or script)
func interact():
  -> Door: play "open" animation
  -> Door: disable collision

# On the Player's sheet
On Every Tick
  -> Player | InteractionBehavior: Focus Nearest Interactable  "interactable", 64

On "interact" pressed
  Condition: Player | InteractionBehavior  Has Focus
    -> Player | InteractionBehavior: Interact With Focus
```

Add a second door, a chest, and a sign, and not one row above changes.

### 2. A prompt label that appears and disappears

On Focus Changed is the only place the prompt needs touching.

```
On Focus Changed
  Condition: Player | InteractionBehavior  Has Focus
    -> HUD Kit: set label "Prompt" text to "Press E"
    -> HUD Kit: show "Prompt"
  Condition: (else)
    -> HUD Kit: hide "Prompt"
```

Because the trigger is an edge, this runs once per approach and once per departure, not sixty times a second.

### 3. Highlighting the focused object

The Juice pack's Start Blinking is the highlight, and Focused Node is what you point it at.

```
On Focus Changed
  Condition: Player | InteractionBehavior  Has Focus
    -> Juice: Start Blinking on  Player | InteractionBehavior.Focused Node
  Condition: (else)
    -> Juice: Stop Blinking on  (the last highlighted node)
```

Keep the previously focused node in a variable if you need to stop the blink on it specifically - the trigger tells you the new focus, and your variable remembers the old one.

### 4. A prompt that names the thing

Read the focused node to write a better prompt than "Press E".

```
On Focus Changed
  Condition: Player | InteractionBehavior  Has Focus
    -> HUD Kit: set label "Prompt" text to  "Press E to use " + Focused Node.name
```

Give your objects readable names in the scene tree and the prompt writes itself.

### 5. Talking to an NPC

Conversations are just an `interact()` that starts a Dialogue Kit conversation.

```
# On the NPC
func interact():
  -> Dialogue Kit: start conversation  "mara_intro"

# On the Player
On "interact" pressed
  Condition: Player | InteractionBehavior  Has Focus
    -> Player | InteractionBehavior: Interact With Focus
```

The player's sheet has no idea what a conversation is, which is exactly the point.

### 6. Handling a thing that has no interact() of its own

Some objects are too simple to deserve a script. On Interacted covers them.

```
On Interacted
  Condition: node is in group  "coin"
    -> CurrencyLedger: Add  "gold", 1
    -> node: queue free
```

The pack fires On Interacted whether or not the thing had a function, so plain nodes are first-class interactables.

### 7. A reach that changes with the tool you hold

`within` is a parameter, so it can be an expression.

```
On Every Tick
  -> Player | InteractionBehavior: Focus Nearest Interactable  "harvestable", Player.tool_reach
```

Equip a longer-handled tool, raise `tool_reach`, and the reach grows with no other change.

### 8. Separate groups for separate interactions

Nothing says you have to use one group - just pick the one that matters right now.

```
On Every Tick
  Condition: Player.mode  ==  "combat"
    -> Player | InteractionBehavior: Focus Nearest Interactable  "enemy", 48
  Condition: Player.mode  ==  "explore"
    -> Player | InteractionBehavior: Focus Nearest Interactable  "interactable", 64
```

Switching modes retargets the whole system, and On Focus Changed fires cleanly at the switch.

### 9. Suppressing interaction during a cutscene

Clear Focus makes the prompt vanish without moving the player.

```
On Cutscene Started
  -> Player | InteractionBehavior: Clear Focus

On Every Tick
  Condition: game is not in a cutscene
    -> Player | InteractionBehavior: Focus Nearest Interactable  "interactable", 64
```

Stopping the per-frame pick freezes the focus; clearing it once makes sure the prompt goes with it.

### 10. A locked door that refuses politely

The refusal belongs to the door, so the player's sheet stays the same.

```
# On the Door
func interact():
  Condition: Door.locked
  Condition: Player does not have  "brass_key"
    -> Toast: show "It is locked."
  Condition: (else)
    -> Door: open
```

The prompt still appears for a locked door, which is correct - the player should know it is a door.

### 11. Picking up items deliberately

Focus-then-press pickups let the player walk past things they do not want.

```
# On the Item
func interact():
  -> Inventory: add  self.item_id
  -> self: queue free

On Interacted
  -> Juice: play sound  "res://sfx/pickup.ogg"
```

The item owns the inventory add; the player's sheet adds the shared feedback for every pickup.

### 12. A hold-to-interact revive

Interact With Focus is a single moment, so hold behavior lives in your own timer.

```
On Every Tick
  Condition: "interact" is held
  Condition: Player | InteractionBehavior  Has Focus
    -> Player: add delta to hold_timer
  Condition: "interact" is not held
    -> Player: set hold_timer = 0

On Every Tick
  Condition: Player.hold_timer  >=  2.0
    -> Player | InteractionBehavior: Interact With Focus
    -> Player: set hold_timer = 0
```

Has Focus doubles as the "am I still standing over them" check, so walking away cancels the hold for free.

### 13. A sound when something new comes in reach

The edge means the sound plays once per approach.

```
On Focus Changed
  Condition: Player | InteractionBehavior  Has Focus
    -> Juice: play sound  "res://sfx/focus.ogg"
```

Try this with a per-frame check instead and you get a buzzsaw; the edge is what makes it pleasant.

### 14. Getting into a vehicle

The car's `interact()` does the seating; the player clears its own focus on the way in.

```
# On the Car
func interact():
  -> Game: set driving = true
  -> Player: hide

# On the Player
On Interacted
  Condition: node is in group  "vehicle"
    -> Player | InteractionBehavior: Clear Focus
```

Clearing the focus stops the "Press E" prompt from hovering over a car the player is already inside.

### 15. Only allowing interaction with what you can see

Pair with the Line Of Sight pack so a chest behind a wall is not focusable.

```
On Every Tick
  -> Player | InteractionBehavior: Focus Nearest Interactable  "interactable", 96

On "interact" pressed
  Condition: Player | InteractionBehavior  Has Focus
  Condition: Player | LOSBehavior  Has Line Of Sight To  Focused Node.global_position
    -> Player | InteractionBehavior: Interact With Focus
```

The prompt still shows for an occluded object, so add the same LOS condition to your prompt row if you want it hidden too.

### 16. A quest board that advances a quest

Boards, altars, and shrines are one-function objects.

```
# On the Board
func interact():
  -> Quest: advance  "gather_herbs"

On Interacted
  Condition: node is in group  "quest_board"
    -> Juice: pulse the HUD quest icon
```

The board owns the quest logic; the player's sheet owns the flourish.

### 17. Debugging what the player is looking at

Focused Node prints straight into a HUD label.

```
On Every Tick
  Condition: game is in debug mode
    -> HUD Kit: set label "Debug" text to  "focus: " + str(Focused Node)
```

Watching that label while you walk around is the fastest way to tune your `within` reach.

### Other use cases

**Multi-player focus.** Give each player their own `InteractionBehavior` and each keeps an independent focus, so two players can stand at the same chest and only the one who presses the key opens it.

**Companion AI that uses the world.** Attach the behavior to a follower, run Focus Nearest Interactable on a `lootable` group, and let the follower call Interact With Focus on its own schedule.

**Context-sensitive key labels.** Read the focused node's own `prompt_text` property in On Focus Changed so each object writes its own prompt - "Open", "Read", "Talk", "Board".

**Interaction cooldowns.** Guard the interact row behind a cooldown so a repeatedly-mashed key cannot fire `interact()` twenty times in a second on the same object.

**Analytics on player attention.** Log every On Focus Changed to see which props players actually walk up to and which ones they never notice - a cheap heatmap of curiosity.

---

## Tips and common mistakes

- **The behavior goes on the player, not on the thing.** This is the single most common mix-up. The player is what has a position, a reach, and a focus; the chest just has an `interact()`. If you attach one behavior per chest, every chest starts scanning the world for itself.
- **Run Focus Nearest Interactable every frame.** It is designed for that. The change guard means the trigger stays quiet, so there is no cost to being correct about where the player is standing right now. Running it on a timer instead makes the prompt lag behind the player.
- **Nothing happens if the group name is wrong.** A typo in the group name simply means no candidates, so the focus is always nothing and the prompt never appears. Check the group spelling on the node and in the row first when a prompt refuses to show.
- **Add groups persistently.** A group added at runtime without persistence will not be saved into the scene, and the check silently never fires. Set groups in the Scene dock so they ship with the scene.
- **`within` is in pixels, and it is a radius.** 64 is roughly a character's width in a 2D game; try 32 for tight, deliberate interaction and 128 for a forgiving one. Too large a reach makes the focus jump between distant objects and the prompt flicker.
- **The trigger's node can be nothing - handle that branch.** Half of On Focus Changed's job is telling you the player walked away. If your prompt never hides, you are probably only handling the Has Focus branch.
- **Put object logic in `interact()`, game logic in On Interacted.** "This door opens" belongs to the door. "Every interaction plays a click and counts toward an achievement" belongs to the player's sheet. Splitting them that way keeps both sides short.
- **Interact With Focus with nothing focused does nothing.** It is safe to call unguarded, but gating it behind Has Focus is still worth it, because it lets you play a "nothing there" sound in the else branch.
- **Distance is measured from the behavior's host, not from a hand or a camera.** For a top-down game that is exactly right. For a side-scroller where reach should be in front of the character, add a facing check of your own alongside Has Focus.
- **Ties go to whoever was checked first.** Two objects at exactly the same distance are decided by group order, which is not meaningful. If overlapping interactables are common in your game, separate them by a few pixels or narrow the reach.
