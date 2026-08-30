# Around Objects: Picking, Layers, Text And The Browser

Four small families that are all about the things AROUND an object rather than about what the object
does.

**Picking** says which instances the rows below are about: the nearest one, a random one, every one
that passes a test, the one you remembered by id. **Layers and Z order** say where an object draws:
in front of its siblings, on the HUD layer rather than the world one, or hidden with the whole layer
it sits on. **Text** is the drawn styling of a label - size, colour, alignment, wrapping, the font
itself. **Browser and platform** are what the game asks of the machine it is running on: open a link,
copy something for the player to paste, go fullscreen, and branch on which system this is.

These are builtin rows, available from any sheet with nothing to enable. Every template compiles to
plain Godot: `pick_random`, `filter`, `instance_from_id`, `z_index`, `reparent`, theme overrides,
`OS` and `DisplayServer`. Nothing here has a plugin dependency at runtime.

Each row is also the AUTHORING half of a reading. Opening a hand-written script as an event sheet
shows the same sentences these rows do, because a row writes exactly the shape the reading
recognises - so a picked row and a typed line are the same bytes and read the same either way.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A turret that shoots the closest enemy**, without a loop or a throwaway variable.
- **A random drop, a random spawn point, a random taunt** out of whatever is in the world.
- **"Every enemy with more than half health"** as one row that names its result.
- **Remembering which one** across a save, a table or a signal, by id rather than by reference.
- **A HUD that never gets covered** by anything in the world.
- **A card that lifts to the top** while it is being dragged.
- **Damage numbers in the right colour and size** without a theme per number.
- **A label that wraps** instead of running off the edge in German.
- **A share button** that opens a link, and a copy button that hands the player a code.
- **One build that behaves on phones, desktops and in a browser.**

## Core concepts

- **A pick NAMES what it found.** Every picking row takes a name, and the rows below it use that
  name. That is the whole difference between a pick and a loop: a loop runs its body once per
  instance, a pick hands you one thing (or one list) to talk about afterwards.
- **A pick can find nothing.** An empty list has no nearest, no random and no top. Ask whether the
  name holds something before you act on it, exactly as you would after a Find.
- **Pick Where hands back a LIST, not one instance.** It is the "pick by comparison" of an event
  sheet: the rows under it run over what it kept.
- **A UID is how you remember WHICH one** in a save file, a table or a variable. A reference cannot
  be written to disk; a UID can, and Pick By UID reads it back - or finds nothing, if that instance
  is gone.
- **Layers beat Z order, always.** An object on a higher layer draws over everything on a lower one,
  whatever the Z orders say. Set Z order sorts within a layer; Move to layer changes which layer.
- **A CanvasLayer is the layer proper.** It has its own order and its own visibility, so one row
  hides a whole HUD. A plain node used to group things sorts the same way but has neither.
- **Move to top of layer does not touch any Z order.** It reorders this object among its siblings,
  which is what "bring the card I just picked up to the front" actually means.
- **Text styling here is per CONTROL, over the theme.** It is the exception, not the system: a
  project that styles every label this way has re-invented a theme by hand, badly.
- **Translated is not a styling row.** `tr("HELLO")` looks up the key in the game's own language and
  falls back to the key itself. Wrap the text, then style the label.
- **Feature tags age better than platform names.** Is On Web and Is On Mobile keep working when a new
  system arrives; Is Platform "Android" does not.

## Reference tables

Ships as is the template the row compiles to. Where a template carries `{uid}`, the editor bakes a
short per-row id into the local's name when you drop the row, so two of the same row in one script
never collide.

### Nodes: Picking

| Name | What it does | Ships as |
|------|--------------|----------|
| Pick Nearest | Keeps the instance closest to a position, and names it | a walk of the list keeping the smallest `distance_to` |
| Pick Farthest | Keeps the instance furthest from a position, and names it | the same walk, keeping the largest |
| Pick A Random One | One instance at random out of the list | `var {name} = {list}.pick_random()` |
| Pick Where | Every instance the test holds for | `var {name} = {list}.filter(func({item}): return {test})` |
| Pick Top | The last instance in the list | `var {name} = {list}.back()` |
| Pick Bottom | The first instance in the list | `var {name} = {list}.front()` |
| Pick By UID | Finds one instance again from the id it was remembered by | `var {name} = instance_from_id({uid_value})` |

### Layers

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Z Order | Where this object draws among the others on its layer | `z_index = {order}` |
| Set Z Order Absolute | Counts the Z order from the layer instead of the parent | `z_as_relative = false` |
| Set Z Order Relative | Counts the Z order from the parent (Godot's default) | `z_as_relative = true` |
| Move To Top Of Layer | Draws over every sibling, touching no Z order | `move_to_front()` |
| Move To Bottom Of Layer | Draws behind every sibling | `get_parent().move_child(self, 0)` |
| Move To Layer | Moves this object onto another layer | `reparent({layer})` |
| Set Layer Order | Where a whole layer sits among the others | `layer = {order}` |

Showing and hiding a whole layer is the shipped **Set Visible** / **Set Invisible** rows: a
CanvasLayer's `visible` is the same property every other object has, and one row for both is why an
opened script can tell a hidden sprite from a hidden layer at all.

### Text

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Font Size | The size this control draws its text at | `add_theme_font_size_override("font_size", {size})` |
| Set Font Colour | The colour the text draws in | `add_theme_color_override("font_color", {colour})` |
| Set Outline Colour | The colour of the outline around the text | `add_theme_color_override("font_outline_color", {colour})` |
| Set Font | Gives this one control its own font | `add_theme_font_override("font", {font})` |
| Set Word Wrap On | Wraps long text at word boundaries | `autowrap_mode = TextServer.AUTOWRAP_WORD` |
| Set Word Wrap Off | Keeps the text on one line | `autowrap_mode = TextServer.AUTOWRAP_OFF` |
| Translated | What a translation key says in the game's language | `tr({key})` |

Alignment has no row of its own yet. A row would carry the engine constant as its value, so a
hand-written line would open reading `set horizontal alignment to HORIZONTAL_ALIGNMENT_CENTER` where
the reading says `Set horizontal alignment to centre` - and the reading is the promise. Set Property
reaches `horizontal_alignment` meanwhile, and an opened script still reads it in the sheet's words.

### Browser

| Name | What it does | Ships as |
|------|--------------|----------|
| Go To URL | Opens a web address outside the game | `OS.shell_open({url})` |
| Request Fullscreen | Takes the game fullscreen | `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` |
| Leave Fullscreen | Puts the game back in a window | `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)` |
| Alert | A plain system message box that stops everything | `OS.alert({message})` |
| Vibrate | Buzzes a phone or tablet | `Input.vibrate_handheld({milliseconds})` |

Copying text to the clipboard is the shipped **Copy To Clipboard** row, under Utility: Window with
the rest of the clipboard family.

### Platform

| Name | What it does | Ships as |
|------|--------------|----------|
| Is Platform | True on one named system | `OS.get_name() == {platform}` |
| Is On Web | True in a browser build | `OS.has_feature("web")` |
| Is On Mobile | True on Android and iOS builds | `OS.has_feature("mobile")` |
| Is On Desktop | True on Windows, macOS and Linux builds | `OS.has_feature("pc")` |

## Use cases

**1. A turret that fires at the closest enemy.** Every tick, Pick Nearest of the "enemy" group to the turret's own position into `target`, then, when `target` exists, turn toward it and shoot. No throwaway "best distance" variable and no loop in sight.

**2. A homing missile that keeps its lock.** Pick Nearest once when the missile is created, remember the target's UID, and every tick Pick By UID to get it back - so the missile keeps chasing the one it started on, and gives up cleanly when that one is destroyed.

**3. A random loot drop.** On Died, Pick A Random One of the loot table's list into `drop` and create it at the enemy's position.

**4. A random spawn point.** Pick A Random One of the "spawn" group and place the new enemy there, which is one row instead of an index and a size.

**5. Every enemy near death.** Pick Where the health fraction is under a quarter into `hurt`, then run the finisher effect over what it kept.

**6. A shop that only shows what you can afford.** Pick Where the price is at or under the player's gold, and build the list from that.

**7. The oldest and the newest.** Pick Bottom of the trail list to fade the oldest segment, Pick Top to attach the newest one - both without an index.

**8. Remembering the selected unit across a save.** Store the unit's UID in the save record, and Pick By UID on load. A reference could never have been written to the file.

**9. A HUD that never gets covered.** Put the HUD on its own CanvasLayer and Set Layer Order to a number above the world's - nothing in the world can draw over it, whatever its Z order.

**10. A pause overlay.** Set Invisible on the pause layer and Set Visible again on resume, instead of showing and hiding a dozen controls.

**11. A card that lifts while dragged.** On drag start, Move To Top Of Layer; on drop, Move To Bottom Of Layer or nothing at all. The whole "which card is on top" problem, in two rows.

**12. A character who walks behind and in front of scenery.** Set Z Order from the character's own Y position every tick, so walking down the screen brings them forward.

**13. Moving an effect out of its owner.** When a spell finishes, Move To Layer the "FX" node so the particles outlive the caster and keep drawing where they were.

**14. Damage numbers that read at a glance.** On a hit, Set Font Size by how big the hit was and Set Font Colour red for damage, green for healing.

**15. A disabled menu option.** Set Font Colour grey and stop reacting to clicks - no second scene, no theme variation.

**16. A label that survives translation.** Set Word Wrap On and give the box a width, so the German string wraps instead of running off the edge.

**17. A title in the game's own font.** Set Font on the title label only, leaving every other control on the project theme.

**18. A tutorial line in the player's language.** Set Text to Translated "TUTORIAL_MOVE", so the key lives in the translation file and the row never has to change.

**19. A share button.** Go To URL the game's page, under the button's own On Clicked event.

**20. A "copy my seed" button.** Copy To Clipboard the run's seed, then show a "copied" label for a second - the whole feature is two rows.

**21. A fullscreen toggle that works in a browser.** Request Fullscreen under the button's On Clicked (a browser only grants it from a real click) and Leave Fullscreen under Escape.

**22. Touch controls on phones only.** Under Is On Mobile, show the on-screen stick; under Is On Desktop, hide it and show the key hints instead.

**23. Hiding the quit button on the web.** Under Is On Web, Set Invisible on the quit button, because a browser tab cannot be quit from inside.

**24. A haptic hit.** On the player being hit, Vibrate for 60 ms. It does nothing on desktop, so it can stay in every build.

**25. A crash report the player can paste.** Alert the message, Copy To Clipboard the version and the last error, and Go To URL the bug form.

### Other use cases

**A stealth cone that picks its victim.** Pick Where the enemy is inside the cone, then Pick Nearest
of what is left - two rows that together read like the sentence you would say out loud.

**A photo mode.** Move To Layer the UI's own layer for everything you want out of the shot, take the
screenshot, and move it back.

**A minimap that draws in order.** Set Z Order from a marker's importance, so the player's blip is
always over the terrain blips without a second layer.

**A results screen that grows to fit.** Set Font Size from how long the name is, and Set Word Wrap On
for the ones that still do not fit.

**A demo build that says so.** Under Is Platform "Web", set the title label's text to the demo one
and Go To URL the full version's page from the buy button.

## Tips and common mistakes

- **A pick that found nothing is not an error, and not a warning either.** Check the name exists
  before the rows that use it, the way you would after any Find.
- **Pick Where gives you a list.** Putting a "call Hit on it" row straight under it calls Hit on the
  list, not on each member. Loop over what it kept.
- **Pick A Random One on an empty list errors in Godot.** Guard it with a count check, or use the
  shipped empty-safe Random Node In Group.
- **A UID is not stable across runs.** It identifies an instance while the game is running. Save it
  inside a run (a checkpoint, a table, a signal payload), never between runs.
- **Z order does not cross layers.** If a HUD element is behind the world, the fix is the layer, not
  a bigger number.
- **Move To Layer keeps the world position, not the local one.** That is usually what you want, and
  it is worth knowing when the object jumps somewhere unexpected.
- **A theme override wins over the theme, and stays won.** Setting a colour on hover and never
  setting it back leaves the control that colour forever.
- **`horizontal_alignment` is a Label's, not every control's.** A Button has its own `alignment`, and
  a LineEdit has neither.
- **Word wrap needs a width.** A label that can grow forever never wraps, however the mode is set.
- **A browser will refuse fullscreen from a timer.** It has to come from something the player did, so
  keep the row under a click.
- **Alert stops the game.** It is for the one thing that must be read before anything else happens -
  not for anything the game itself can say on screen.
