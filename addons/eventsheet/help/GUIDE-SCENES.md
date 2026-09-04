# Scenes: Travelling To Them, Layering Them, and Saving What The Player Built

A Godot scene is two things wearing one word, and almost every confusion in this corner of the
vocabulary comes from mixing them up. A scene is **a place the player travels to** - the title
screen, level three, the shop. A scene is also **a file holding a branch of nodes** - a chest, a
bullet, a menu panel you drop in ten times.

The sheet keeps those two apart on purpose, and it does it in the words:

- The place you travel to is a **Layout**. Go To Layout, Restart Layout, Add Layout On Top.
- The file holding nodes keeps the word **Scene**. Spawn Scene Instance, Save Node As Scene, Scene
  File Is Data-Only.

Everything on this page is Godot's own scene tree said in sentences: owners, process modes,
viewports, `node_added`, `PackedScene.pack`, the editor's undo manager. There is no scene manager
autoload here, no wrapper node type, and no second registry of scene names. What you build is what a
Godot programmer would have written by hand, and a project that already wrote it opens as these rows.

## Table of Contents

1. [Name the one node you mean](#name-the-one-node-you-mean)
2. [A layout on top of the running game](#a-layout-on-top-of-the-running-game)
3. [Saying where, in three dimensions](#saying-where-in-three-dimensions)
4. [Hearing a node arrive](#hearing-a-node-arrive)
5. [Saving what the player built](#saving-what-the-player-built)
6. [The trust line a scene file comes back through](#the-trust-line-a-scene-file-comes-back-through)
7. [Changing somebody's scene from a tool](#changing-somebodys-scene-from-a-tool)
8. [Three small dignities](#three-small-dignities)
9. [A second picture of the world you are already in](#a-second-picture-of-the-world-you-are-already-in)
10. [Tips and common mistakes](#tips-and-common-mistakes)

## Name the one node you mean

Drag a node out of the Scene dock into a parameter field and it lands as a path:
`$UI/Bars/HealthBar`. That is correct, and it is correct only until somebody moves the bar - into a
margin container, under a new panel, one level up to make room. Then the path names nothing, the
row is silently about a node that is not there, and the change that broke it happened in a scene
file nobody was thinking about the sheet while editing.

Godot already solved this, and the answer is a habit rather than a feature. Tick **Access as Unique
Name** on a node in the Scene dock and it gains a `%` mark: from then on `%HealthBar` finds it
anywhere under the scene root, at any depth, whatever anybody reparents it to.

**The sheet speaks that word in both directions.** The object step of the Add picker opens with a
**%names** section listing the marked nodes of the scene this file runs in, each beside the class
the `.tscn` says it is. Picking `%HealthBar` scopes the picker to a ProgressBar's own vocabulary
rather than a bare Node's, and the row that lands is written on that node by name.

![The Add picker with its first section headed %names in this scene - the nodes this scene marked scene-unique - listing %HealthBar as a ProgressBar and %ScoreLabel as a Label, above the System group and the project's own classes](images/unique-names-picker-section.png)

Read the other way, a line somebody already wrote on a `%Name` reads as a row on that object, with
that class's own words and its icon, rather than as an anonymous call:

<!-- caption: Two marked nodes, four lines, one event -->
```gdscript
# A HUD whose two named nodes are the objects its rows sit on. Both marks are Godot's own - ticked in
# the Scene dock, stored in the .tscn - and nothing here was generated: the sheet reads these lines
# exactly as they are written, and re-emits them byte for byte.
extends Control

var player_hp: int = 100
var score: int = 0


func _process(_delta: float) -> void:
	if player_hp < 25:
		%HealthBar.show_percentage = false
		%HealthBar.indeterminate = false
		%ScoreLabel.set_modulate(Color(1.0, 0.3, 0.3))
		%ScoreLabel.text = "%d" % score
```

![The four lines above, and the one event they read as: an Every tick event whose condition is player_hp under 25, with four action rows whose object column reads HealthBar ProgressBar twice and ScoreLabel Label twice, over a sheet head declaring the two instance variables](images/unique-name-rows.png)

**Nothing is registered.** The mark lives in the scene file and nowhere else, so there is no second
list of names to keep in step, and a name the scene stops carrying simply stops resolving: the row
falls back to plain code, and the Doctor's `%token` check is the one place that says so. The sheet
itself says nothing at all about it.

**Make the mark from where you are.** A field holding `$UI/Bars/HealthBar` offers **Make %HealthBar
unique** on its help strip: one click ticks that node's own *Access as Unique Name* and rewrites the
field. It is a scene edit, not a sheet edit, so it lands in the editor's own undo history and Ctrl+Z
in the scene puts the checkbox back. The offer appears only when there is something to do - never
for the scene root, for a node this scene does not own, or for one already marked.

**When somebody renames the node anyway.** A row reaching `$Torch` after the node became `WallTorch`
wears the quiet amber state, and the sentence appears in the help strip under the selected row and
in the Doctor's Renames section: *"$Torch is gone from crypt.tscn. That same save gained $WallTorch -
point the rows there, or leave them and pick the node yourself."* Nothing appears in the sheet
itself, and nothing moves until you press the button, which shows every row it would change first.

That offer is **evidence, never a guess**. It is made only when that scene's own last save shows the
old name going out and one name coming in - one save, one file, one swap. A near name that was in
the scene before the save did not arrive; a save that brought several nodes is answered only if
exactly one of them is a near spelling; a save that proved nothing leaves a plainly amber row with
no door, and you pick the node yourself. A rename made while the editor was closed is always that
plain case, because the evidence is a file changing under a running editor.

**The `%` mark is what stops this happening in the first place.** A row written on `%HealthBar`
survives every reparent, so the only rename that can break it is a rename of the node's own name -
which is rarer, and one line of a receipt rather than a path's worth. The amber state above is the
safety net for the paths you have not marked yet, not a reason to stop marking them.

Naming a whole **scene** by a short word instead of a path is a different job, and the Named Scenes
pack owns it. This is about one node inside one scene.

## A layout on top of the running game

A pause menu is not a new layout and it is not a spawned enemy. The game underneath has to keep
existing - its nodes, its variables, its half-finished tween - while something sits over it.

Three rows say exactly that:

| Name | What it does | Ships as |
|------|--------------|----------|
| Add Layout On Top | Puts a layout over the running game under a name you choose | the name asked about first, then load and instance, name it, `get_tree().root.add_child(…)` |
| Remove Layout On Top | Takes it back off by that name (a name nothing is under does nothing) | `get_tree().root.get_node_or_null({layout_name})`, guarded, then `remove_child` and `queue_free()` |
| Layout Is On Top | True while it is still there | `get_tree().root.get_node_or_null({layout_name}) != null` |

**Under the tree root, not under this node.** That is the one design decision in the row, and it is
the reason a menu survives the layout beneath it changing. A copy added under the node that spawned
it dies with that node, which is exactly right for an enemy and exactly wrong for an inventory. It
is also why the Scene Flow pack parents its fade overlay to the same root.

**The name is the node's own name under the root.** Nothing keeps a registry of it; `get_node_or_null`
is what answers, which is why the three rows have to agree on the spelling and why a close row is
safe to run twice.

**One name, one layout.** `add_child` will not take a name a sibling already has - it renames the
newcomer to something like `@Node@2` - so a second add under one name would leave a copy that
neither of the other two rows could ever find or remove, sitting under the tree root for the rest of
the run. Add Layout On Top therefore asks the name first and loads nothing when it is already up.
And the removal takes the node **off the tree** before freeing it, because `queue_free` frees at the
end of the frame: a node only queued is still a child, still found by name, and still in the way.
That is what makes the familiar pair - remove it, then add it again - work in one frame.

Here it is as people actually write it, and as it reads back:

<!-- caption: A pause menu put over the running game -->
```gdscript
extends Node


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		var menu = load("res://pause_menu.tscn").instantiate()
		menu.name = "PauseMenu"
		get_tree().root.add_child(menu)
		get_tree().paused = true
```

Its twin is the same event with the question inverted: cancel pressed *while* `Layout Is On Top`
answers true runs Remove Layout On Top and unpauses. Two events, told apart by one condition.

![Two events side by side: cancel pressed with no menu up adds the layout and pauses the game, cancel pressed with it up removes the layout and unpauses, with the plain GDScript both compile to underneath](images/layout-on-top-pause-pair.png)

**Pause The Game is the row this pairs with, and the process-mode table is the one thing to know
before you use it.** `Set Game Paused` writes `get_tree().paused`, and what that means for any node
is decided by that node's own **Process Mode**:

| Mode | What it means |
|------|---------------|
| Inherit | Follow the parent |
| Pausable | Stop when the game pauses |
| When Paused | Run **only** while the game is paused |
| Always | Ignore the pause entirely |
| Disabled | Never run |

A pause menu added over a paused game is paused with it unless the menu layout's **own root node**
is set to Always or When Paused. Set that on the layout's root in the scene, or with **Keep Node
Running While Paused** on the way in. The row does not write it for you - it emits the three lines
it names and nothing else - and the parameters dialog says so on the help strip while the Layout
field has focus, which is the moment it matters.

The neighbours, so nothing is mistaken for anything else: **Go To Layout** replaces what is running.
**Spawn Scene Instance** adds a copy under *this* node with a bare `add_child`, which is the right
reading for a spawned enemy. These three leave the game running underneath and outlive it.

## Saying where, in three dimensions

Spawning is the same sentence in 3D as in 2D - instance, parent, place, in that order - so the 3D
rows are the 2D pair with a Node3D host and Vector3 answers to "where". There is no second spawning
idea to learn:

- **Spawn A Copy (3D)** - instance, parent, place.
- **Spawn A Copy Safely (3D)** - the same spawn added on the next idle moment, for a collision
  handler. It places *before* it parents, because a copy that is not in a tree yet has nothing for a
  global position to be global to.

What changes with the dimension is only the words for **where**, and there are four of them. Each is
one expression, so each also works in a Move To, a camera target, or any other field taking a
Vector3:

| Name | What it gives you | Ships as |
|------|-------------------|----------|
| Place Of (3D) | A node's own place in the world | `{node}.global_position` |
| Random Place Inside Box | An evenly spread point inside a box you drew | `({box} as Node3D).to_global(…)` |
| Random Place Inside Sphere | An evenly spread point through a ball | `({ball} as Node3D).to_global(… * pow(randf(), 1.0 / 3.0))` |
| Random Place Around (3D) | A point on a ring around a node, on the ground plane | `{node}.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * {radius}` |

![Two events on a 3D sheet: an every-tick event, gated on the spawners group gaining its first member, whose sub-events ask whether SpawnBox is a CollisionShape3D and spawn a copy of Enemy at a random place inside it, with an Else spawning at a random place inside a CSG box; and an On Timeout event spawning a flanker on a ring around the player](images/scenes-spawn-3d.png)

Three things are worth knowing, and all three are visible in the emitted line:

- **The box reads two kinds of box** - a CollisionShape3D holding a BoxShape3D (the one on the Area3D
  you drew round a spawn zone) and a CSGBox3D you blocked the space out with. The casts in the
  emitted expression are what let one row ask which it is: a node reached by path is a plain Node
  until something says otherwise, and GDScript will not read `size` off one that has not.
- **The sphere corrects by the cube root, not the square root.** The 2D disc pulls its radius back by
  a square root so points do not bunch in the middle; a solid ball needs the cube root, because the
  volume inside a radius grows as its cube. The direction is three normal draws normalised, which is
  the one spelling evenly spread over a sphere - picking two angles at random bunches points at the
  poles.
- **Random Place Around (3D) is a ring, not a disc.** Every point is exactly the radius out, level
  with the node it is around. Add to the Y yourself when the copy should drop in from above.

**There is deliberately no 3D Random Place Off Screen Edge.** In 2D a screen edge is a rectangle in
the plane the game is played in, which is why that row can be one honest expression. In 3D "just off
screen" is a question about a camera's frustum - which camera, how far along its forward axis, at
what depth - and every one-line answer to it is a guess that looks right until the camera moves.
Nothing is offered in its place: a wave that must arrive from off camera is spawned at a Marker3D or
inside a box the level designer drew, which is what Place Of (3D) and Random Place Inside Box
already say.

## Hearing a node arrive

Wiring something up to every member of a group is a job with two halves, and most projects only ever
write the first one. **Connect Group Signal** wires a listener to every member the group has *right
now* - that is its stated limit, and it is the present tense. The future tense is a trigger:

| Name | What it does | Ships as |
|------|--------------|----------|
| On Node Joins Group | Runs the moment a node belonging to a **Group** enters the world | `get_tree().node_added.connect(_on_node_joined_group)`, with an Is In Group condition under it |
| On Node Leaves Group | Runs the moment one leaves | `get_tree().node_removed.connect(_on_node_left_group)`, with the same condition under it |

Together they are the whole observer story: connect the present, catch the future, and a group that
grows all game long stays wired without ever re-running the loop.

**The filter is a row you can see.** Picking either trigger puts the shipped **Is In Group**
condition in the sheet with the group already filled in. Nothing new was minted for it and nothing
is added behind the row - it is a plain `if` on disk, and deleting it is allowed:

<!-- caption: A minimap that keeps itself in step with what exists -->
```gdscript
extends Node2D


func _ready() -> void:
	get_tree().node_added.connect(_on_node_joined_group)
	get_tree().node_removed.connect(_on_node_left_group)


func _on_node_joined_group(node: Node) -> void:
	if node.is_in_group("minimap"):
		add_marker_for(node)


func _on_node_left_group(node: Node) -> void:
	if node.is_in_group("minimap"):
		remove_marker_for(node)
```

![Two events on a minimap sheet: a node joining the minimap group adds a marker and wires the node, a node leaving it removes that marker, each with its Is In Group condition drawn as an ordinary row under the trigger](images/scenes-group-arrivals.png)

Three things are stated rather than hidden, and the help strip says all three while the Group field
has focus:

- **The check runs for every node entering or leaving the world**, not only for members of the group
  you named. At the scale a game moves nodes around at - a spawn, a pickup, a room's worth of props
  - that is one group lookup and nothing worth measuring. Inside a particle storm, an emitter adding
  hundreds of nodes a frame, it is the wrong tool.
- **A group written in a scene file is set before the node enters the tree**, so the guard sees it. A
  group a script adds *after* `add_child` is not there yet when the join is announced, and that node
  is simply not matched. Add the group before the node enters the tree, or on the row that spawns it
  (which is what Spawn A Copy Into The Crowd does), and the two agree.
- **Any group is a stated choice**, not a blank. Choosing it leaves the guard off entirely, so the
  event answers every node entering or leaving the world - the firehose a debug overlay or an editor
  tool wants.

**Neither of these is On The Last One Destroyed**, and neither is the aggregate pair. On Group
Emptied and On Group Gains First Member compare this tick's count with last tick's and say "the wave
is over" or "combat started"; these two say *which* node, at the moment it happens. On The Last One
Destroyed is the same `node_removed` signal narrowed to one moment, and it asks two further
questions of its own: whether the node is really being destroyed rather than reparented, and whether
it was the last one.

## Saving what the player built

A level editor, a base builder, a ship yard: the player assembles nodes while the game runs, and
that branch has to survive the game closing. **Save Branch As Scene File** writes it out as a `.tscn`
under `user://`.

**The owner walk is the whole row, and it is the trap it exists to answer.** `PackedScene.pack`
writes out the root plus every node that root **owns** - and a node added while the game runs is
owned by nothing at all. So a plain pack-and-save writes a scene holding one node, returns OK twice,
and loads back empty. Nothing reports it, because nothing failed.

The row walks the branch first and gives every ownerless node under it the branch root as its owner,
and the walk is emitted into your script where you can read it. Here is the shape written by hand -
the row writes the same program, with both failures answered as well:

<!-- caption: The owner walk, written by hand -->
```gdscript
extends Node


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"save_level"):
		var branch := $Level
		for part: Node in branch.find_children("*", "", true, false):
			if part.owner == null:
				part.owner = branch
		var scene := PackedScene.new()
		scene.pack(branch)
		ResourceSaver.save(scene, "user://built_level.tscn")
```

A node that already belongs to an instanced scene keeps its own owner, and is saved as that instance
rather than as a copy of its insides. Both failures are answered out loud: a pack can refuse a node
that is not in a tree, and a write can fail on a missing folder, a full disk or a read-only path.
Either one prints through the debugger rather than leaving no file and no word.

**The walk borrows, and gives it back.** The row's own lines remember which nodes it adopted and set
their owner back to nothing the moment the pack is done. That is not tidiness: save the Room, then
save the Level the Room is in, and without the give-back the Level's file comes back holding a
*childless* Room - the props belong to the Room now, and a pack writes out only what the root owns.
Both engine calls still answer OK and nothing is reported, which is exactly the failure the walk
exists to prevent. Giving the ownership back also means the row leaves your running game as it found
it: a save is a save, not an edit.

**The Save To field says which place it is writing into.** Every path field in the plugin carries a
muted lead under the box naming `user://` (the player's folder: writable, one per player, survives
updates) or `res://` (the game's own files, read-only once exported). The export trap is visible
where it is made:

![The Save Branch As Scene File parameters dialog, titled with the sentence it is about to write, holding a Branch field and a Save To field whose muted lead under the box names the user folder as writable, one per player, surviving updates](images/scenes-save-place-lead.png)

**Editor Tools ▸ Save Node As Scene is the same job on the other side of the line.** That row packs
the node you are *editing*, from a Tool sheet, where the Scene dock has already set every owner.
This one runs in the game, where nothing has an owner until somebody sets one. Two rows, one job,
two worlds - reach for the one whose world you are in.

## The trust line a scene file comes back through

Then the file comes back, and here is the turn. A `.tscn` is a table of resources, and a resource may
be a **script**. Building one runs that script with everything your game can reach. That is exactly
right for a scene you shipped and exactly wrong for one that arrived from somewhere else, and
nothing about the path tells them apart: your own build and a file copied off a forum land in the
same folder under the same name.

So **Scene File Is Data-Only** is the question to ask above the row that builds one:

```
On load pressed
+ Scene file "user://built_level.tscn" is data-only
  -> Add Layout On Top  "user://built_level.tscn", "Built"
```

It reads the file's own resource table as **text** and builds nothing, so asking is safe on a file
from anywhere. It answers false for a scene carrying a script inside it, and for a scene that points
at **anything at all** outside `res://` - a script, another scene, a `.tres`. Not only scripts,
because a scene that names another scene names a file with a table of its own, and this reading
opens the one file you gave it. So a true answer means *nothing comes in with this file that the
game did not ship with*, which is a promise it can keep.

It reads **tags as tags**, because that is what Godot's own parser reads: `type = "Script"` with
spaces around the `=` is the same tag as `type="Script"`, and a tag may run over two lines. The
threat here is a file somebody wrote by hand, so "the editor does not write it that way" is not an
answer - both of those spellings load the script they name. And anything it cannot read as a scene
table - a tag that never closes, a resource with no type, a binary `.scn`, a file that is not there
- answers false, because an unfamiliar file is not a file that has been cleared.

It reads the **node bodies** too, because a body line carries no tag at all and the engine's value
parser reads it anyway: `script = Resource("user://mod.gd")` is resolved by loading that path and
`script = Object(GDScript,"script/source":"...")` by making the object and compiling the source
inside it, neither of them writing a resource tag for a tag-reader to find. Both constructors are
refused wherever they appear; the honest `ExtResource(` and `SubResource(` are matched on a word
boundary and pass. A resource tag carrying a **backslash** is refused as well: Godot decodes escapes
in a tag and this reading compares the letters as written, so the two would disagree about what a
type is called, where a path goes and where the tag ends.

**A true answer means the file brings no code of its own. It does not mean the file is inert.** A
cleared scene may still hold a `[connection]` naming one of *your* methods with arguments of its own,
an `Animation` track calling one of your methods at a keyframe, or a node with an
`instance_placeholder` that loads another scene when something calls `create_instance()` on it. None
of those brings a stranger's code in; every one of them can reach yours. A scene from outside is
still somebody else's **data**, and the methods it can reach are worth the same thought as any other
input.

**A question mentioned is not a question answered.** `if not <the question>` and `if debug or <the
question>` both run the body on exactly the files the question refused, so neither counts as a guard
- the row still wears the amber state and the Doctor still reports it. Inverting the condition row
in the sheet reads the same way, for the same reason.

![Two events above the GDScript they compile to: a save key press running Save branch Level as scene file into the user folder, and a load key press whose scene-file-is-data-only condition guards an Add layout on top row, with the owner walk, the pack and the guarded load visible in the code panel below](images/scenes-save-branch.png)

**The Doctor is where the words are.** A row that builds a scene from a path written in the line and
not under `res://`, with no such question anywhere around it, is reported in Doctor ▸ Files. It is a
**warning**, not an error, for the same reason the mod rule beside it is: a game whose mods *are*
scenes with scripts is a decision some projects make on purpose. What is not a decision is making it
without knowing. Its one-click answer writes the question itself into the event, in front of
whatever it already asks, as an ordinary condition row you can edit or delete afterwards.

**Nothing of this appears in the sheet.** The row wears the quiet amber state and says not one word
there. The sentence and the door live in the Doctor's inbox and in the help strip under the selected
row, which is where you are already looking when you want them:

![The Project Doctor inbox with one line under Warnings, marked new since you last looked: the check reads Files untrusted scene load, names the file, and the finding says the file builds a scene the game did not ship with and that a scene file can name a script, with one chip beside it offering to ask whether it is data first](images/scenes-trust-inbox.png)

The wider rule this is one case of: **user content is data, never code.** A picture arrives as a
texture, text as text, a table as rows and columns. A scene file is the one file a game writes that
can carry behaviour back in, which is why it is the one with a question in front of it.

## Changing somebody's scene from a tool

An editor tool that adds, removes or moves nodes in the scene somebody has open is changing a
document they are in the middle of editing. If it does that the direct way, the change lands and
their next Ctrl+Z walks straight past it into whatever they were doing before.

Three rows make the same three changes through the editor's own undo manager instead:

| Name | What it does |
|------|--------------|
| Set Property (Undoable) | Changes one property of a node in the open scene, reading the node once and the value still in place for the undo half |
| Add Node (Undoable) | Adds a node under a parent, owner set so it is saved with the scene, and a reference held so redo puts back the same node |
| Remove Node (Undoable) | Takes a node out, reading its parent and its place among its siblings while it still has both, so the undo half puts it back where it was, in order, with its owner restored |

They compile to plain `EditorInterface.get_editor_undo_redo()` - the engine's own manager, with no
plugin anywhere in the emitted file.

**One event is one gesture, and that is the whole point.** You do not open or commit the action
yourself. The compiler opens it before the first undoable row of an event and commits it after the
last, naming it after that event's own trigger, so every undoable row of one event lands as **one**
step and one Ctrl+Z takes the whole thing back. Ordinary rows standing between two undoable ones stay
inside the gesture, where you put them.

![A snap-the-props tool event holding Set Property (Undoable), a plain print row between, and Add Node (Undoable), with the GDScript underneath showing one create_action at the top, the do and undo pairs in the middle, and one commit_action at the bottom](images/undoable-tool-edits.png)

It cannot nest, either. The bracket opens and closes inside one event body with nothing held between
fires, so a tool on a per-frame trigger leaves one clean entry per fire rather than a growing pile of
half-open actions.

**These rows are editor-only.** On a game sheet the picker does not offer them, and one that gets
there by being pasted is left out of the compile with the trigger it was under named in the warning.
The editor's undo history is the editor's, and a running game has none.

**A tool that changes the open scene the plain way wears the quiet amber state**, with the sentence
in the Doctor's **Tool edits** section and in the help strip under the selected row, and a one-click
**Make it undoable** door that swaps the row for its undoable twin - same values under the same
names. The rule only asks it of a Tool sheet reaching for the scene the editor has open: an ordinary
`@tool` node script setting its own properties is simply correct.

For a change none of the three rows covers, the paired do/undo recipe by hand lives in a GDScript
block inside your On Editor Run event, and the Editor Tools guide writes it out.

## Three small dignities

Three lines a scene-building project writes all the time used to read as something vaguer than they
are. Each of these lands *beside* the row it clarifies - the plain spelling is frozen and unchanged,
and both emit the same call:

- **`x.owner = y` is not a property being poked.** It says which scene the node belongs to, which is
  what decides whether it is written out when that scene is packed - the very thing the owner walk
  above exists to set. So it reads as **Set Scene Owner**, the write half of the read-only Get Scene
  Owner.
- **`x.duplicate(<flags>)` reads as Duplicate Node (choosing)**, with the three boxes the flags
  really are: signals, groups, scripts. A pooled copy that must not inherit the original's
  connections, a template cloned without its script. A bare `x.duplicate()` stays the frozen
  **Duplicate Node** it always was, because Godot's default - all three come along - is right often
  enough.
- **`reparent(x, false)` reads as Reparent To (choosing)**, in Add Child (existing node)'s own two
  words: *keeping its place* leaves the node exactly where it looks, *snapping to it* puts it at the
  new parent's spot. A bare `reparent(x)` stays plain **Reparent To**. The difference between the two
  rows is one honest argument, written down rather than left off.

![Three pairs of node rows: making a crate part of a level, a plain duplicate beside one naming Godot's own duplicate flags, and a bare reparent beside one that says snapping to it, with the GDScript each pair compiles to underneath](images/node-dignities.png)

## A second picture of the world you are already in

Sometimes the answer is not another scene at all: it is a second *view* of the one that is running.
A minimap, a security monitor on a wall screen, a portrait of a character standing in the room. The
**Second View** pack is that, and it ships as the `SecondView` autoload.

A view is a SubViewport **sharing the running world**, plus a camera of its own that follows a node
you name. Four rows and one expression are the whole vocabulary: **Make A View**, **Show View In**,
**Set View Zoom**, **Stop View**, and **View Texture Of** for the places a frame cannot reach - a
material's albedo, a shader parameter, a theme icon.

![One event on the canvas: On created, then Make a view named "minimap" following $Player at zoom 0.25, then Show view "minimap" in $HUD/MinimapFrame](images/second-view-rows.png)

![A 2D level of coloured blocks seen close up, with a small yellow player square in the middle, and in the top right corner a bordered panel showing the same level from much further back with the yellow marker in it](images/second-view-running.png)

**The node you follow decides which kind of view you get.** A Node2D gets a Camera2D on the running
2D world; a Node3D gets a Camera3D looking straight down at it on the running 3D world. You never
pick, because the node already said it, and a node that is neither warns by name and builds nothing
rather than half a view. Zoom means the same in both: below 1 shows more of the world, above 1 shows
less.

**The frame sizes the render.** A view shown in a 200 by 120 TextureRect renders 200 by 120 pixels
rather than being stretched out of a square, and follows that panel when the window resizes. There
is no size row to learn: the frame you already placed is the answer.

Everything it builds stays ordinary Godot - a SubViewport named `View_<the name>` parented to the
autoload, with an ordinary camera inside it - so you can aim it, mask it, or hang another pack off
that camera exactly as you would any other. Split screen is two views in two frames, and the pack's
own guide shows it in two sentences.

The neighbours: **Named Scenes** answers *which* scene you travel to. **Render Scene To Image** is
the one-shot editor cousin that photographs a scene file. Drawing shapes onto a texture stays the
Drawing Canvas pack's job. This one is a live picture of the world you are already in.

## Tips and common mistakes

- **A path breaks quietly; a `%name` does not.** If a row is about one particular node of the scene,
  tick Access as Unique Name on it once and stop thinking about where it lives. The offer to do that
  is on the field's own help strip.
- **A menu added under this node dies with this node.** Add Layout On Top parents under the tree root
  for exactly that reason. If your pause menu vanishes when the level changes, that is the bug.
- **A pause menu paused with the game is a Process Mode, not a bug in the row.** Set the *menu
  layout's own root node* to Always or When Paused.
- **A packed scene saves what its root OWNS.** Nodes added while the game runs own nothing, so a
  plain pack writes a scene holding one node and reports success. Save Branch As Scene File does the
  owner walk first, in lines you can read - and hands the borrowed ownership back afterwards, which
  is what lets you save a room and then the level it is in without the second file coming back short.
- **Ask before you build a scene you did not ship.** A `.tscn` can name a script. Scene File Is
  Data-Only reads the file's table as text and answers before anything runs.
- **A group joined in `_ready` is joined too late for On Node Joins Group.** `node_added` is emitted
  before `_ready` runs, so that node is never matched by the trigger at all - not "matched later".
  Join the group before the node enters the tree, or on the row that spawns it.
- **Every member of a group leaves during teardown.** Freeing a branch, or quitting, announces a
  departure for each one, so an On Node Leaves Group body runs against a tree that is being taken
  apart. Write it so that is harmless.
- **An editor tool that skips the undo manager costs your teammates their history.** One event is one
  gesture; there is nothing to open or commit yourself.
- **Nothing on this page renders a warning inside the sheet.** A row with something to say about it
  goes quietly amber and no further. The words and the fix doors are in Tools ▸ Project Doctor and in
  the help strip under the selected row.
