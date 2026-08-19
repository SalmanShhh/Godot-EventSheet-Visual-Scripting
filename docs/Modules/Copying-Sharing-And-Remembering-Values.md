# Copying, Sharing And Remembering Values

Four small families that are all "copy this thing somewhere else".

**Share codes** turn any value into one pasteable line of text and read it back: a run seed, a loadout,
a colour preset, a whole save record. **The clipboard rows** move text and images between your game
and the rest of the operating system, in both directions. **Clone Into** copies a live node, adds it,
places it and groups it, in one row. And **Remember / Restore** puts a named copy of any value aside
for this run - the before-value for a preview, a buff, or a cutscene.

These are builtin rows, available from any sheet with nothing to enable. Every template compiles to
plain Godot: `DisplayServer`, `Marshalls`, `duplicate` and `add_child`, `set_meta`. Nothing here has a
plugin dependency at runtime.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [How share codes work](#how-share-codes-work)
4. [Reference tables](#reference-tables)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Seed sharing** - "here is the run I just had", as one line in a chat box.
- **Loadout codes** - a build a player can post on a forum and a friend can paste in.
- **Colour and cosmetic presets** shared between players.
- **A "copy my stats" button** on the results screen.
- **A paste box** that refuses garbage before it reaches the game.
- **Screenshot import** - the player copied an image, you show it.
- **Duplicating a live node** - a decoy, a split enemy, a stamped decal.
- **Preview then cancel** - try a hat on, restore the old one when the player backs out.
- **Before-and-after values** for a buff, a debuff or a cutscene.
- **A cheap undo** for one value, with no undo stack to build.

## Core concepts

- **A share code is one line of text.** No spaces, no newlines, so it survives copy and paste through
  a chat client. It carries an `EF1.` tag so text that is not a code at all can be refused instantly.
- **Share codes keep TYPES.** An int comes back an int, a Vector2 comes back a Vector2, and nested
  Arrays and Dictionaries keep their shape. That is why they are not JSON, which flattens every number
  to a float and has no Vector at all.
- **A share code cannot build objects.** The decoder refuses to instantiate them by default, so a
  hostile code a player pastes in cannot construct anything.
- **The clipboard is the operating system's, not the game's.** Copy To Clipboard writes to the same
  clipboard the player's browser uses. Read it back with Clipboard Text, and gate on
  Clipboard Has Text or Clipboard Has Image first.
- **There is deliberately no "On Clipboard Changed".** The shipped **Has Changed** condition already
  turns any expression, including Clipboard Text, into an edge.
- **Clone Into is the LIVE-node twin of Spawn Scene.** Spawn Scene starts from a `.tscn` file on disk;
  Clone Into starts from a node already in the world. The shipped Duplicate Node is an expression whose
  own help tells you to add the clone yourself, so the everyday copy would otherwise cost three rows
  and a scratch variable.
- **Remember / Restore is keyed by NAME, in node metadata.** Exactly like the named cooldowns. A
  Remember in one row and a Restore in a completely different event agree with no declared variable
  between them and no member state.
- **Remembering lasts for this run only.** Nothing here survives closing the game. For memory that
  does, use the **Remember Between Runs** option on the variable, the **Only Once Ever** condition, or
  the Save System pack.

## How share codes work

A code is the tag `EF1.` followed by base64 of Godot's own binary Variant form. That choice buys three
things:

1. **Lossless types.** `Marshalls.variant_to_base64` round-trips the value exactly, where JSON would
   turn every number into a float and could not represent a Vector at all.
2. **One safe line.** No spaces or newlines, so a chat box, a forum post or a text field cannot break
   it up.
3. **No object construction.** `base64_to_variant` refuses to build objects by default, so a pasted
   code from a stranger cannot instantiate anything.

**Share Code Is Valid** runs three cheap tests before the decoder is ever reached: the `EF1.` tag,
then the two shape facts every base64 payload has (a length that is a multiple of 4, and at least one
4-character group). Ordinary pasted prose is refused without the decoder being called at all, and the
realistic bad paste - a code a chat client truncated - fails the length test three times out of four
and is refused in silence too. Only a tagged, correctly-shaped, still-corrupt payload reaches the
decoder, which logs an engine line when it refuses. That is why the condition's own description says to ask
the question when the pasted text CHANGES rather than every frame.

One more thing worth knowing: a code made from nothing at all also reads as invalid.

## Reference tables

Ships as is the template the row compiles to. Where a template carries `{uid}`, the editor bakes a
short per-row id into the local's name when you drop the row, so two of the same row in one script
never collide.

### Utility: Window - share codes

| Name | What it does | Ships as |
|------|--------------|----------|
| Share Code For | Turns any value into one compact line of text a player can paste anywhere | `("EF1." + Marshalls.variant_to_base64({value}))` |
| Copy Share Code To Clipboard | Encodes a value as a share code and puts it straight on the OS clipboard | `DisplayServer.clipboard_set("EF1." + Marshalls.variant_to_base64({value}))` |
| Share Code Is Valid | True when the text really is a share code that decodes cleanly | The tag test, a length test, a multiple-of-4 test, then `Marshalls.base64_to_variant(...) != null` |
| Value From Share Code | Reads the value back out of a share code, nothing when the text is not one | `(Marshalls.base64_to_variant(str({code}).trim_prefix("EF1.")) if str({code}).begins_with("EF1.") else null)` |

### Utility: Window - the clipboard

| Name | What it does | Ships as |
|------|--------------|----------|
| Copy To Clipboard | Copies text to the OS clipboard | `DisplayServer.clipboard_set({text})` |
| Clipboard Text | Whatever text is on the OS clipboard right now | `DisplayServer.clipboard_get()` |
| Clipboard Text Is | Compares the clipboard text against a value, with your choice of operator | `DisplayServer.clipboard_get() {op} {value}` |
| Clipboard Has Text | True when the OS clipboard currently holds any text | `DisplayServer.clipboard_has()` |
| Clipboard Has Image | True when the OS clipboard currently holds an image | `DisplayServer.clipboard_has_image()` |
| Clipboard Image | The image currently on the OS clipboard | `DisplayServer.clipboard_get_image()` |

### Nodes

| Name | What it does | Ships as |
|------|--------------|----------|
| Clone Into | Copies a live node, adds the copy to a parent, places it and optionally groups it | `var __clone_{uid} = {source}.duplicate()`, `{parent}.add_child(__clone_{uid})`, a position write guarded by a Node2D / Node3D / Control test, and `add_to_group(StringName({group}), true)` when the group is not blank |

Its parameters are **Copy** (the live node), **Into** (where the copy is added), **At** (a world
position, a Vector3 for a 3D node) and **Group** (optional, blank means none).

### Run Context - remember for this run

| Name | What it does | Ships as |
|------|--------------|----------|
| Remember Value As | Copies any value aside under a name, in memory, for this run | `set_meta(&"__ef_mem_" + str({name}), {value})` |
| Restore Value Into | Pours a remembered value back into a variable, leaving it alone when nothing was remembered | `{var_name} = get_meta(&"__ef_mem_" + str({name}), {var_name})` |
| Remembered Value | The value remembered under a name, or your fallback when there is none | `get_meta(&"__ef_mem_" + str({name}), {fallback})` |
| Has Remembered | True when something was remembered under that name this run | `has_meta(&"__ef_mem_" + str({name}))` |
| Forget Remembered | Drops a remembered value, so Has Remembered reads false again | `if has_meta(...): remove_meta(...)` |

## Use cases

**1. A "copy seed" button.** One row does the encoding and the clipboard write together.

```
On copy seed pressed
  -> Copy Share Code To Clipboard  run_seed
  -> show "Seed copied."
```

```gdscript
func _on_copy_seed_pressed() -> void:
	DisplayServer.clipboard_set("EF1." + Marshalls.variant_to_base64(run_seed))
```

**2. Show the code instead of copying it.** Share Code For is the expression form, for a label, a text
box, or a QR generator.

```
On results screen opened
  -> set CodeBox.text = Share Code For(run_seed)
```

**3. A paste box that refuses garbage.** Ask the question when the text CHANGES, not every frame.

```
On CodeBox text changed
  Condition: Share Code Is Valid  CodeBox.text
    -> set PasteButton.disabled = false
  Else
    -> set PasteButton.disabled = true
    -> show "That does not look like a valid code."
```

**4. Read the value back in.**

```
On paste pressed
  Condition: Share Code Is Valid  CodeBox.text
    -> set run_seed = Value From Share Code(CodeBox.text)
    -> start the run
```

**5. Share a whole loadout, not just a number.** Share codes keep nested structure and types, so a
dictionary of lists round-trips exactly.

```
On share build pressed
  -> Copy Share Code To Clipboard  {"weapon": weapon_id, "perks": perk_list, "tint": armour_colour}
```

The `armour_colour` comes back a Color, not three floats.

**6. Paste straight from the clipboard, with no text box at all.**

```
On import pressed
  Condition: Clipboard Has Text
  Condition: Share Code Is Valid  Clipboard Text()
    -> set loadout = Value From Share Code(Clipboard Text())
    -> apply the loadout
  Else
    -> show "Copy a build code first."
```

**7. Notice when the clipboard changes.** There is no clipboard trigger, and there does not need to
be: Has Changed turns any expression into an edge.

```
Every Frame
  Condition: Has Changed  Clipboard Text()
    Condition: Share Code Is Valid  Clipboard Text()
      -> show the "Import this build?" prompt
```

**8. Copy a support code for a bug report.**

```
On report bug pressed
  -> Copy To Clipboard  "build " + version + " / " + Date & Time Text() + " / " + last_error
  -> show "Details copied. Please paste them into the report."
```

**9. React to a specific clipboard value.** Clipboard Text Is takes an operator, so it is not only
equality.

```
On cheat box submitted
  Condition: Clipboard Text Is  ==, "iddqd"
    -> enable the debug overlay
```

**10. Import a screenshot the player copied.**

```
On paste image pressed
  Condition: Clipboard Has Image
    -> set AvatarTexture.texture = ImageTexture.create_from_image(Clipboard Image())
  Else
    -> show "Copy an image first."
```

**11. Duplicate a live node.** Clone Into is the one-row form of duplicate, add, place and group.

```
On decoy cast
  -> Clone Into  Player, get_parent(), Player.global_position + Vector2(48, 0), "decoys"
```

```gdscript
func _on_decoy_cast() -> void:
	var __clone = Player.duplicate()
	get_parent().add_child(__clone)
	if __clone is Node2D or __clone is Node3D or __clone is Control:
		__clone.global_position = Player.global_position + Vector2(48, 0)
	if not str("decoys").is_empty():
		__clone.add_to_group(StringName("decoys"), true)
```

The group is added persistently, so the clone keeps it if the scene is later packed.

**12. A slime that splits when it dies.**

```
On slime died
  -> Clone Into  self, get_parent(), global_position + Vector2(-16, 0), "enemies"
  -> Clone Into  self, get_parent(), global_position + Vector2(16, 0), "enemies"
```

**13. Preview a hat, then cancel.** Remember before you change anything, restore on cancel.

```
On hat previewed
  -> Remember Value As  "hat", equipped_hat
  -> set equipped_hat = hovered_hat

On preview cancelled
  -> Restore Value Into  "hat", equipped_hat
  -> Forget Remembered  "hat"
```

**14. Only undo a preview that actually happened.** Has Remembered is the gate on the Cancel button.

```
On preview cancelled
  Condition: Has Remembered  "hat"
    -> Restore Value Into  "hat", equipped_hat
    -> Forget Remembered  "hat"
```

**15. Restore is safe when nothing was remembered.** The variable keeps what it already had, so a
Restore with no matching Remember is a no-op rather than a value wiped to nothing.

```
On cutscene ends
  -> Restore Value Into  "camera_zoom", camera_zoom
```

**16. Read a remembered value without pouring it back.** Remembered Value takes a fallback, so there
is always an answer.

```
Every Frame
  -> set DeltaLabel text = "was " + str(Remembered Value("health", health))
```

**17. Show the before-and-after of a buff.**

```
On buff applied
  -> Remember Value As  "attack", attack
  -> set attack = attack * 1.5
  -> show "Attack " + str(Remembered Value("attack", 0)) + " -> " + str(attack)

On buff expired
  -> Restore Value Into  "attack", attack
  -> Forget Remembered  "attack"
```

**18. Stash a value across two completely different events.** Nothing is declared between them; the
name is the whole connection.

```
On cutscene starts
  -> Remember Value As  "hud_visible", HUD.visible
  -> set HUD.visible = false

On cutscene ends
  -> Restore Value Into  "hud_visible", HUD.visible
```

**19. A one-value undo.** Remember before every change and the last one is always recoverable.

```
On colour picked
  -> Remember Value As  "colour", chosen_colour
  -> set chosen_colour = new_colour

On undo pressed
  Condition: Has Remembered  "colour"
    -> Restore Value Into  "colour", chosen_colour
```

**20. Clear the stash when a run ends**, so a stale value from the last run cannot leak into the next.

```
On run ended
  -> Forget Remembered  "hat"
  -> Forget Remembered  "attack"
```

Forgetting a name that was never remembered is harmless.

### Other use cases

**Daily challenge codes.** Encode the day's seed and modifier list as one share code shown on the menu, so two players comparing scores can prove they ran the same challenge.

**Character creator export.** Share Code For over the whole appearance dictionary gives a paste-anywhere string, and a paste box guarded by Share Code Is Valid imports someone else's character with the colours intact.

**Level editor clipboard.** Clone Into duplicates the selected live node at the cursor and puts it in an `editor_placed` group, so the editor's own selection logic finds only what the player stamped.

**Difficulty preview.** Remember the current tuning values, apply the previewed tier so the player can see the numbers change, and restore them the moment they move the selector away.

**Support diagnostics.** Copy To Clipboard with the version, the platform and the last error line turns "it crashed" into a bug report the player can paste in one keystroke.

## Tips and common mistakes

- **Ask Share Code Is Valid when the text CHANGES, not every frame.** A code mangled in transit can
  still reach the decoder, and the engine logs a line each time it is refused. On Text Changed or a
  Paste button is the right home for it.
- **A code made from nothing reads as invalid.** If you share a value that was never set, the paste
  side refuses it and the reason looks like a corrupt code.
- **Share codes are not a security boundary.** They are readable by anyone who cares to decode them,
  so do not put a secret in one. What they do guarantee is that pasting one cannot construct objects.
- **Share codes are not JSON and are not readable.** If you need a human to be able to read or edit the
  payload, use the JSON rows in the Working With Files guide instead - and accept that JSON flattens
  numbers and has no Vector.
- **Copy Share Code To Clipboard is not the same as Copy To Clipboard.** The first encodes the value
  first. Passing an already-encoded code to it would encode the code itself.
- **Reading the clipboard blindly can give you an empty string.** Clipboard Text has no guard of its
  own; gate on Clipboard Has Text when the difference between "empty" and "nothing there" matters.
- **Clipboard Has Image and Clipboard Text are separate questions.** An image on the clipboard does not
  make Clipboard Has Text true, and Clipboard Image on a clipboard with no image gives nothing useful.
- **The clipboard is shared with the whole machine.** Writing to it overwrites whatever the player had
  copied. Only write on an explicit action, never on a timer.
- **Clone Into's At is only used when the copy has a position.** The template tests for Node2D, Node3D
  or Control, so cloning a plain Node ignores the value rather than erroring. Pass a Vector3 for a 3D
  node.
- **A cloned node carries everything the original had**, including its script's current values and
  whatever the original was in the middle of. Clone from a clean template node when that matters.
- **Use Spawn Scene when you are starting from a `.tscn`.** Clone Into is for a node already alive in
  the world; Spawn Scene (Full) is the file-on-disk equivalent, with the same position, rotation and
  group idea.
- **Remembered values live on the NODE, keyed by name.** Two sheets on the same node share the name;
  two different enemies each have their own. Typos are silent - `"hat"` and `"Hat"` are two different
  memories, and the second one has nothing in it.
- **Nothing remembered survives closing the game.** Remember Value As is in-memory only. For memory
  that persists, use the Remember Between Runs option on a sheet variable, the Only Once Ever
  condition, or the Save System pack.
- **Restore Value Into leaves the variable alone when nothing was remembered.** That is the safe
  behaviour, and it also means a Restore that seems to do nothing is usually a name mismatch rather
  than a broken row. Check with Has Remembered.
- **Forget what you remembered.** A Remember with no matching Forget keeps the old value alive for the
  rest of the run, so a Cancel button pressed much later can restore something from an entirely
  different context.
