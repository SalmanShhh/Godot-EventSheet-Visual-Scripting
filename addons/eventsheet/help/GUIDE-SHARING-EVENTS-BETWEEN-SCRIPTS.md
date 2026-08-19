# Sharing Events Between Scripts

Some events belong to more than one script. Pausing. The cheat keys you keep meaning to delete. The
three rows every enemy needs. Copying them into six scripts works right up until you fix a bug in
one of the six.

A **shared event sheet** is an ordinary script whose whole job is to be included by others. There is
no new file format and no registry, and nothing here needs the plugin at run time: underneath, a
shared sheet is either inheritance or composition, which is to say ordinary Godot.

## The two gestures

**`Sheet ▸ New shared sheet…`** makes one. It asks two things - what it is called, and the one
question that belongs to the shared sheet rather than to each script that includes it:

| Included | What it means | Reach for it when |
| --- | --- | --- |
| **as a base class** | The including script `extends` it, so the shared sheet's events simply *are* that script's events | The including scripts have no base class of their own |
| **as a helper** | The including script keeps one of it, calls it each tick and forwards its triggers to it | The script already extends something (a `CharacterBody2D`, a pack's class) and cannot extend anything else |

![The New Shared Sheet window: a name, the one wiring choice, and a live "Ships as" line reading class_name PauseHandling  ·  as a helper](images/shared-sheet-new.png)

**`Add ▸ Include sheet…`** wires the open script to one. It asks nothing at all, because the wiring
was already decided - pick the shared sheet, and the rows that wire it are written for you.

## What the two wirings write

A shared sheet made **as a base class** is a `Node` script with a `class_name`, and including it
rewrites exactly one line of the includer:

```gdscript
extends PauseHandling
```

That single line is why the choice matters: a script can only extend one thing.

A shared sheet made **as a helper** is a `RefCounted` with a handler per moment it wants to run at -
`on_ready`, `on_tick`, `on_physics_tick`, `on_input` - and including it writes the member and the
forwarding rows, exactly as you would write them by hand:

```gdscript
var _pause_handling := PauseHandling.new()


func _process(delta: float) -> void:
	_pause_handling.on_tick(self, delta)


func _input(event: InputEvent) -> void:
	_pause_handling.on_input(self, event)
```

Only the handlers the shared sheet actually declares are forwarded. Writing a forwarding row for a
function that is not there would compile to a call that fails the moment it runs.

## Reading an includer

The included events read in the includer greyed and foldable, under the **Include bar** at the top of
the reading, which names the shared sheet. They are editable only in their own sheet: clicking one
goes there. Changing the shared sheet changes every script that includes it, which is the whole
point and also the thing to be careful about.

## What the Doctor says about includes

One thing, and it is the one thing you cannot see by reading the includer:

> Two included sheets handle Every tick - PauseHandling and CheatKeys. Both run, in include order,
> and the last one wins.

Both handlers really do run, and the second one's answer is the one that lasts - but neither handler
is written in the file you are looking at, so nothing on screen would ever tell you. It is reported
as a note rather than a warning, because occasionally it is exactly what someone meant.

## Tips and common mistakes

- **Decide the wiring by what the includers already extend**, not by taste. A script that must be a
  `CharacterBody2D` cannot take a base class, and that is the whole of the decision.
- **A shared sheet is a normal script.** Open it, read it, test it, commit it. Nothing about it is
  special except the one marker line in its header that records how it is included.
- **An include is written into the FILE**, so the open sheet is saved first. A sheet that has never
  been saved as a script has nowhere to write one.
- **Including the same shared sheet twice is refused**, in words, rather than quietly writing a
  second member that shadows the first.
- **Prefer a called function when you mean "run this here, now".** A shared sheet gives a script a
  whole set of events with their own triggers; if what you want is "these five actions, at this
  point", extract them to a function and call it - the call is a row you can see.
