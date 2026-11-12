# Changelog

The work not yet released is listed first, under `[Unreleased]`. Each released version keeps its full notes in its own file under `docs/changelog/`, and the index at the bottom of this file lists them newest first. A release moves its section out of `[Unreleased]` into `docs/changelog/vX.Y.Z.md` when it is cut.

## [Unreleased]

### Removed: the Project bar

- The Project strip at the foot of the Objects rail is gone, with its View > Project bar item and the saved on/off choice. It listed scenes, scripts, classes, sounds and files, which Godot's FileSystem dock and Quick Open already do. A scene, script or sound is opened, found or dragged the Godot way. Dragging a class, sound or scene out of that strip onto the canvas is gone with it; drag from the Objects list or the FileSystem dock instead.
- The Welcome page's "coming from another event-sheet editor" answer no longer switches the bar on, and its summary lines no longer mention it. The two Project bar colours are gone from the theme tokens. The word the familiar vocabulary used for the FileSystem dock is now "FileSystem dock", and the editor-tool row that reveals a file reads "Show in FileSystem dock" (its id and the code it writes are unchanged).
- The Start page's "This editor" card now just opens the plugin's own script as a sheet.

### Removed: the Objects list no longer lists the rest of the scene

- The "Also in the scene" section is gone. It repeated Godot's Scene dock. The list keeps the objects the sheet itself uses, with their counts, the filter, the right-click menu and dragging onto the sheet. The tab's hover no longer counts the scene's other nodes.

### Removed: object marks - Godot's groups and exported variables decide the canvas offers

- The plugin's own per-project "marks" (secret, water, needs key) are gone, together with the store that held them. Dropping an object on the canvas now asks Godot itself: a node in the group `secret` is offered the secrets counter, a node in the group `water` is offered the two rows that raise and lower the in-water flag, and a node whose script exports `needs_key` is offered the door event. Add a node to a group in the Node dock, Groups; the answer lives in the scene file, so it travels with the scene and the plugin keeps nothing. An object the open scene does not hold is offered nothing extra. Old projects that still hold the three metadata keys load as before and ignore them. The Secrets guide, Working In 3D, the Mark Secret Found and Try Door descriptions and the Keycard door starter note say how. The boomer_level showcase puts its SecretRoom in the group `secret`. No emitted GDScript, `ace_id` or block `kind_id` changed.

### Changed: "Instance variables" now reads "Variables"

- The head folder, the Add menu and context menu items, the Add variable shortcut label, the variable list headings in the picker ("Player - variables"), the guided tour, the tutorials and the guides all say "variable" and "Variables" now. The pack folder "Internal state" is unchanged. Only wording changed: no name in the emitted code, no `ace_id` and no block `kind_id` moved. The nine translation files carry the new words.

### Removed: the Properties bar

- The panel to the right of the sheet that showed the selected condition, action, group, class or object as fields is gone, along with its View > Properties Bar item, its drag handle and edge strip, and its width setting. The sheet now uses the full width. Every edit it offered has a place that stays: double-click a parameter for the Edit Parameter dialog, edit a group's name and switch on its own row, and edit the class name, base type, icon, tool switch and description on the sheet's head row. A selected function still opens in Godot's own Inspector. Layouts saved with the bar open or tucked load as before and simply ignore its width.
- The "Change type" question that listed the members an event uses and the new type lacks was only in the bar, so it is gone too.

### Removed: the Object properties window

- Clicking an object's name in a row no longer opens a window. A click there now only selects the row, like a click anywhere else on the cell. The window repeated what Godot already shows: the Scene dock for the hierarchy, the Inspector for values. It also carried a Hierarchy section (add a child by dragging, unparent, flags), a variables table and the buttons Add condition, Add action, Highlight rows, Select in scene and Show in code. Add condition, Add action, Highlight rows and Select in scene are still on the Objects list (right-click or click an entry). Show in code has no other door. Double-clicking an entry in the Objects list or a class in the Project bar opens nothing now, and View > Object Properties is gone. The flags chip on an Add child row stays.

### Removed: the Inspector's variables table

- Selecting a node whose script came from a sheet no longer shows an "Instance variables" table at the top of the Inspector. Godot's own Inspector already lists every `@export` variable of the script as an ordinary row, so the table repeated them. The "Shape ..." link and the Edit Event Sheet button stay.

### Changed: more air between events in the Editor Native look

- Two events in the Editor Native look are now 6 px apart instead of 1, so each reads as its own event and not as a continuation of the one above. The conditions and actions inside one event are exactly as tight as before, and a sub-event still sits 1 px under its parent. The README pictures of the workspace and of the Generated GDScript panel were retaken to show it.

### Changed: clicking beside the sheet clears the selection

- A click in the strip left of the sheet (the side panel's rail) or right of it, outside every event and variable, now clears the selection, the way a click on the empty canvas does. The sheet keeps keyboard focus, so Delete after that cannot reach the Scene tree. Ctrl and Shift clicks there change nothing.

### Added: a behaviour says what it changes on its parent

- A behaviour that writes into the node it works on now says so in its description, which shows in the Add Node window and the Inspector. For example "Changes on its parent: up_direction, velocity, move_and_slide()." A behaviour that only reads its parent says nothing. The line is read from the behaviour's own code each time the pack is built, so it cannot fall out of date.

### Added: Acts on, for a behaviour that is not a direct child

- Every behaviour that works on a node of a certain type (Platformer Movement, Bullet, Anchor, Sine and the rest) now has an Acts on field at the top of its Inspector. Leave it empty and the behaviour works on its parent, exactly as before. Set it, and the behaviour can sit anywhere in the scene, for example under a Behaviours folder node.
- The Doctor and the warning in the Output both say "or set Acts on" as the second way out. Scenes saved before the field existed load with it empty, so nothing in them changes.

### Added: the Doctor says when a behaviour is under the wrong node

- Check the project now reads every scene and says it when a behaviour sits under the wrong kind of node, before the game runs. For example "Platformer Movement is under a Node2D; it needs a CharacterBody2D: put it under one." The finding offers "Move it under <the nearest node that fits>" and "Show in scene".
- A behaviour that cannot find its host says the same words in the Output while the game runs, in place of "PlatformerMovement behavior requires a CharacterBody2D parent." The behaviour scripts stay ordinary scripts that work in any project without the plugin.

### Changed: the Family Arena showcase teaches call down, signal up

- Each Enemy now moves itself: its own sheet has an Every tick row that moves it by its own fall_speed and wraps it back to the top. The arena sheet no longer reaches into the enemies to move them; it spawns them and runs the one rule that is about the whole family, a strike that walks every Enemy with a typed For each (`for enemy: Enemy in ...`) and may hit each one through Enemy: Take Damage. The showcase plays the same: enemies fall, the strike hits them, they die.

### Added: a picked instance is an object in Add action and Add condition

- Inside a pick (a For each, Pop back / front into, Pick nearest / first where / random, a typed local, or a signal that hands the event its instance) and every sub-event under it, Add action and Add condition list the picked instance at the top of the objects page, by its type (Unit, Enemy; its name as written when two picks share a type). Choosing it offers that class's own rows and those of what it is a kind of (Node2D: Set position, Set tint, Hide), each already aimed at the picked name. Outside the pick it is not offered.
- Rows on a picked instance read as that object's rows, whether hand-written or picked: `unit.start_turn()` reads "Unit | Start turn", and a test such as `unit.health < 20` reads "Unit | health < 20". A For each written with a typed item (`for unit: Unit in selected`) is understood as a pick, and a sub-event or an Else under it keeps it.
- Where a row needs a value, the expression picker has a "Picked here" section with the instances the event picked or was handed by its trigger, so Push back, Delete value and Contains do not need the name typed.

### Changed: findings draw no frame, and long sentences are read whole

- A row with a finding is a faint tint and an amber event number (red for one that cannot run). The amber frame round the whole event is gone.
- A finding's sentence that does not fit the status bar is said whole, wrapped, on a line of its own above it, with the doors left in the bar.
- A For each or other loop cell wraps in the condition lane like any other long condition instead of being cut mid-word.

### Added: a pick lasts for its event and its sub-events, and nowhere else

- A For each, a Pop back / front into and a typed local are picks. A row under one that acts on the picked name now shows the picked TYPE in the object column (Unit, Enemy); when an event holds two picks of one type (an attacker and a target) each shows its name as written instead. A sub-event inherits the pick, and a sibling event starts with nothing picked.
- A row that acts on a name another event picked, where nothing by that name is picked, is an amber row. The help strip and the Doctor say "No Unit is picked here", with the doors Pick the Unit from a group (for a declared family) and Pick the Unit from a list (when the sheet has an Array of that type); each adds the pick to the event in one undo step.

### Changed: the pick rows can choose their set from a group or a list

- Pick Nearest, Pick A Random One, Pick Where, Pick First Where, Pick Last Where, Pick Top and Pick Bottom have a "Choose a group or list" dropdown beside their From box. It lists the project's groups first (a group is Godot's way to keep an unordered set of nodes, and it drops a destroyed one by itself), then the sheet's own list variables, then the lists of nodes below the sheet's node. Choosing writes the expression into the box, which stays free text. A pick never removes from the list; to take the picked one out, follow with Delete value.

### Added: a group is Godot's way to keep a set of nodes, and the sheet says so

- An Array of nodes that the sheet never reads by position or order (only push, delete, contains and For each) is an amber row. The help strip and the Doctor say a group is the Godot way and that it drops a destroyed instance by itself. The door Use a group instead rewrites the rows in one undo step: Push back becomes Add to group, Delete value becomes Remove from group, Contains becomes Is in group, For each over the list becomes For each in group, and the list's declaration goes. The door is only offered when every use of the list is one of those.
- An ordered list of nodes that is looped over and never has a destroyed instance taken out of it anywhere on the sheet is amber too, with the door Drop freed instances first, which adds an event above the loop with that row.
- A row that names a list of a parent, a sibling or an Autoload gets a note (never an error): it keeps working, and the words suggest asking that object through a function or a signal.

### Added: three rows for lists of instances

- Push back, once adds a value only when the list does not hold it already (`if not selected.has(unit): selected.append(unit)`). Push back is unchanged, so a deck can still hold two of a card.
- Set to the instances in a group where a test fills a list from a group in one row (`selected.assign(get_tree().get_nodes_in_group("units").filter(func(one): return box.has_point(one.position)))`). When order does not matter, the group itself is Godot's own tool: it forgets a destroyed instance by itself.
- Drop freed instances from a list removes the entries whose instance was destroyed (`selected.assign(selected.filter(is_instance_valid))`), for ordered lists that nothing else cleans.
- Each spelling, written by hand, opens as its row and saves back to the same bytes.

### Changed: a list row reads under its list

- Every row on the Variables: Array page (Push back, Pop back into, Move back to, Clear, Is empty, For each popped...) now shows the list it acts on in the object column, written as the row writes it (`undo_stack`, `$Enemy.draw_pile`), with the variable mark, where it used to say System. Only the reading changed: the rows, their words and the code they write are the same.

### Changed: the Array dropdown offers only the sheet's own lists and those of nodes below it

- The list fields used to offer the arrays of any object in the scene and of every Autoload. They now offer the sheet's own arrays and the arrays of nodes below the sheet's node (`$Child.items`, `%UniqueChild.items`). A parent, a sibling or an Autoload is asked through a function or a signal instead. A row that already names one keeps working and keeps its text when edited.

### Fixed: the shipped-pack warning and the swap refusal say it once, in full

- The warning on the first edit of a shipped behaviour file ("is a shipped behaviour: adding a newer version of the pack replaces this file and your edits.") used to share the status bar with the counts and was cut off. It now has a line of its own above the status bar, at the dock's whole width, wrapped, with the Edit it anyway door beside it.
- Swapping two typed arrays of different types said the same sentence under the field, in the help card and beside Done. It is now said once, under the field; the help card keeps describing the field, nothing is written beside Done, and Done stays blocked.

### Changed: the help card in every window is a plain panel

- The card that explains the focused field (and the Doctor and row help strips built from it) no longer has a coloured outline or a thick coloured left edge. It keeps the thin hairline every inset panel has, like Godot's own docks. Its heading is the muted caption colour; only a warning (amber) or an error (red) colours the heading.
- The one-sentence note under a field (a name already in use, a node not in the scene yet) lost its coloured left edge too. It keeps the faint tint of its tone.
- The small badges beside a page title ("Action", a pack's name) and the chosen cell of the animation frame strip lost their coloured outlines; each keeps its tint. A field that cannot be accepted still shows its red outline, because that one is a state.
### Added: Pop back into and Pop front into, and Stack and Queue groups in the picker

- Taking an item off a list used to be an expression (`Set last to undo_stack.pop_back()`), so a pop hid inside another row, and a pop used twice in one row, or in a condition that runs every frame, silently ate items. The Variables: Array page now has two actions that keep what they took in a name you choose: Pop back of a list into a name (`var last = undo_stack.pop_back()`) and Pop front of a list into a name (`var job = jobs.pop_front()`). Push back is the row it always was.
- The same page gains two groups that only help you find the words: Stack (a stack pushes and pops at the back: last in, first out) lists Push back, Pop back into and Back, and Queue (a queue pushes at the back and pops at the front: first in, first out) lists Push back, Pop front into and Front. A row says the same thing wherever it is listed.
- A hand-written `var name = list.pop_back()` or `pop_front()` opens as its row and saves back to the same bytes.

### Added: an If empty field on the pops, and Back / Front with a fallback

- Popping an empty array prints an error in Godot and hands back nothing. Pop back into and Pop front into now have an optional If empty field. Filled, the row writes `var last = undo_stack.pop_back() if not undo_stack.is_empty() else Vector2i(-1, -1)` and needs no guard. Left blank it is the plain pop, and the row's help says to guard it with Array Is Empty, inverted (the cross), the guard that already exists. The guarded one-line pop opens as the same row.
- Two new expressions, First Item (or a fallback) and Last Item (or a fallback), read the front or the back without removing it and give your own value when the list is empty. First Item and Last Item are the rows they always were.

### Added: Move back / front to, Move all to and Swap, and the Array dropdown offers another object's arrays

- Moving items between two lists is one row now instead of two hand-joined rows and a temporary: Move back of a list to another (`redo_stack.append(undo_stack.pop_back())`), Move front of a list to another (`pop_front()`), Move all of a list to another (`other.append_array(list)` then `list.clear()`, in order), and Swap two lists (a temporary named `__swap_` plus the row's own id, then the two writes, so two swaps in one event never collide). Each opens again from the same hand-written lines and saves back to the same bytes; a swap through any other temporary stays the plain code it is.
- Every list field is the Array variable dropdown, and it now also offers the arrays of the other objects in the scene after the sheet's own: `$Enemy.draw_pile`, `%Deck.cards`, an Autoload's list. A row that already names one keeps it when you edit it, even with that scene closed.
- Swapping two typed arrays of different element types is refused in the parameters window with one line naming both types ("undo_stack is Array[Vector2i] and scores is Array[int], and a typed array only holds its own type."). An untyped Array on either side is not refused.

### Added: For each popped from the front / back of a list

- Working through a queue used to be a While and a take kept in step by hand, where a forgotten pop is a frozen game. Two loop conditions on the Variables: Array page, For each popped from the front of a list as a name and For each popped from the back, run their event once per item and take each item off the list as it is used (`while not spawn_queue.is_empty():` then `var scene = spawn_queue.pop_front()`). The list is empty when the loop ends, and items pushed while it runs are handled too.
- A hand-written `while not L.is_empty():` whose first line takes from the same list opens as this loop and saves back to the same bytes; a while with any other body, `remove_at(0)` instead of `pop_front`, or a take from another list stays the While it is. The "While nothing inside can end" warning stays quiet for it, because the take changes the list. The For Each dialog gains the two matching collection choices so editing the loop never turns it into a plain walk.

### Added: Push back, keeping the last N

- A trail, a replay buffer, an input buffer for combos or the last few chat lines was an append and a trim loop written separately. One action does both: Push back a value to a list, keeping the last N (`trail.append(point)`, then `while trail.size() > 20:` and `trail.pop_front()`). The oldest items drop off the front, so the newest stays. The three-line run opens as this row; a trim written with `if`, or `remove_at(0)` instead of `pop_front`, stays the rows it is today.

### Fixed: a pop knows its type

- Taking an item off an `Array[Vector2i]` left the local untyped, so autocomplete and the type check knew nothing about it. Pop back into and Pop front into over a typed array now write `var last: Vector2i = undo_stack.pop_back()`, and the loop For each popped from the front / back types its item the same way, so `last.` offers `x` and `y` and a wrong use is caught as you type. An untyped Array gives the untyped local it always did, and a hand-written `var last = undo_stack.pop_back()` keeps its spelling (the type is added only when the row is made on the sheet); a hand-written typed pop opens as the row with its type kept.
### Changed: your own scripts have no lock on their functions

- A function in a script you opened (an `On function` event) is now editable like any event from the first click: drag an action, double-click it, Add action, Delete, with no menu step first. Before, every hand-written function opened read-only until you found Make Function Body Editable in its right-click menu. An edit still rewrites only the lines of the rows it changes, and an untouched function still saves byte for byte. The menu item stays for anyone who wants a function read-only, renamed Lock this function / Unlock this function; a locked function reads grey, and a drag on it says which menu item unlocks it.

### Added: a shipped behaviour pack asks once before its first edit

- A script in one of the plugin's own pack folders (under `eventsheet_addons/`, including a pack copied into your project from the library) keeps its function bodies locked. The first drag, double-click, Add action or Delete on one says in the help strip: "<file> is a shipped behaviour: adding a newer version of the pack replaces this file and your edits.", with one door, Edit it anyway. The door unlocks every function in that file; the gesture that asked is not performed, so you repeat it. Undoing an edit never locks the file again.

### Added: lock and unlock choices are remembered for the project

- A function you lock or unlock, and a pack file you unlock with Edit it anyway, stay that way after you close and reopen the editor. They are kept in the project's editor settings, the same place folded regions are, and never in the `.gd`, so the file and a teammate's copy are untouched.

### Fixed: dragging an action inside a function's body moves it

- In a function you wrote by hand (such as an "On function hit" event), dragging one of its actions to reorder it, or onto another event, did nothing at all and said nothing. The drop marker now shows inside the function, the action moves (with its quiet note, if it has one), the file saves with only those lines moved, and Undo puts it back in one step.

### Fixed: expression conditions that name `delta` keep their colour

- Once `delta` stopped being respelled `dt`, a condition such as `entry.integrate(delta)` or `_separate(delta)` stopped being drawn as the coloured expression it had always been (the reader only coloured an expression it had reworded). It reads exactly as written and wears the expression colour again.

### Changed: a `#` note among a function's statements is the note of the action below it

- A `#` line written directly above a statement inside a function is now that action's quiet note (it reads after the action, muted) instead of a separate comment row in the action lane. Moving the action moves its note, copying it copies it, and the file saves back to the same lines. A TODO or FIXME note, a note kept apart from the statement by an empty line, the note that opens a body, a commented-out statement and a `##` documentation line stay comment rows.

### Changed: an untyped variable reads `any`

- `var score` with no type reads `any score` on every row look (the Inspector-style row used to read `Variant score`), with the quiet note "no starting value" where its value would be. A variable that spells `: Variant` keeps the word it wrote.

### Fixed: the Godot-call draw rows start with a capital

- Draw Line, Draw Rectangle, Draw Circle, Draw Arc, Draw Texture and the rest of the Godot-call draw rows read "draw line from a to b" in lower case beside rows that start with a capital. They now read "Draw line from a to b in red", "Set draw transform to ..." and "Redraw" like every other action. Reading only: ids, templates and the code they write are unchanged.

### Changed: the two sets of Draw rows have names that say which is which

- Searching "draw" under an On Draw event listed two Draw Line, two Draw Circle, two Draw Arc and so on: Godot's own `draw_*` calls (picker group "Drawing: Godot calls") and the older rows that paint onto ANOTHER node's canvas. The older rows now read Draw Line On Node, Draw Circle On Node, Draw Rect On Node, Draw Arc On Node, Draw Polygon On Node, Draw Polyline On Node, Draw Text On Node and Draw Texture On Node. Their ids and the code they write are unchanged.

### Fixed: a restored session reads every tab as events, not just the last

- Reopening the editor with several scripts open used to bring back only the last tab as events; the others stayed as raw `function` blocks, because opening each tab dropped the background read of the one before it. The restore now lets each script finish reading before it opens the next, so a restored tab reads exactly like a freshly opened one.

### Fixed: the parameters window no longer writes a call with a gap in the middle

- Setting a later optional argument of a Godot-call row (`draw_line`'s Antialiased, `draw_rect`'s Width) while an earlier optional one was blank used to write `draw_rect(r, c, , 2.0)`. The window now fills every blank optional argument before the last given one with its own default (`draw_rect(r, c, true, 2.0)`), so the call is always valid GDScript; a call with nothing given after a blank still writes the short call, and a lifted short call re-emits byte for byte.

### Changed: a statement written over several lines opens as one row

- A call, an assignment or a `\`-continued line that you wrote over several lines (a `draw_rect(` with its `)` on a line of its own, `bullet.position = Vector2(` with one argument per line) is now one action instead of a block of code. The row shows the statement on one line; double-click it and the parameters window shows the value as you wrote it, line breaks and indents included, and keeps whatever layout you give it. Saving writes the same lines back.

### Changed: constants, plain variables and annotated declarations open as variable rows

- `const SPEED = 160`, `const TAN30DEG = tan(deg_to_rad(30))` and `const BULLET_SCENE = preload("res://player/bullet.tscn")` are variable rows marked as constants, reading the type Godot infers for them (`float`, `PackedScene`) while the file keeps writing none.
- `var score` with no type and no value is a variable row that reads `any` and has no starting value. A type written with a space before its colon (`var tween : Tween`), a hinted export that infers its type (`@export_range(1, 1000) var row_size := 100`) and a `@warning_ignore(...)` line above a variable or a signal stay with their declaration and are written back as they were.

### Changed: the `#` notes of a script open as comment rows

- A note above a function, over a declaration or between two blocks is a comment row written back exactly where it sits, and the notes among a function's statements are comment rows between its actions. `##` documentation lines stay with the function they describe, and a `#region` fence stays a fence.

### Changed: a note at the end of a line stays with its line

- `hide() # why` is the action Hide with the comment "why", `const MOTION_SPEED = 160 # Pixels/second.` shows its note in the variable row's note column, and `if alive: # player only` is the condition Is alive with that note. The spacing before the `#` is kept exactly as you wrote it, and editing the row's values keeps its note.

### Changed: `signal name()` opens as a signal row

- A signal declared with empty brackets is a signal row that remembers the brackets and writes them back; a signal made in the sheet with no values is still written without them.

### Added: Godot's own drawing calls as actions under On Draw

- A new Drawing: Godot calls group holds Godot's `draw_*` calls by their plain names: Draw Line, Draw Rectangle, Draw Rectangle Outline, Draw Circle, Draw Circle Outline, Draw Arc, Draw Polyline, Draw Polygon, Draw Text, Draw Texture, Draw Texture Rect, Draw Texture Region and Set Draw Transform, plus Redraw for `queue_redraw()`. Every field carries Godot's own argument name, and the ones Godot lets you leave off can be left blank, so a hand-written `draw_line(a, b, Color.RED)` opens as the same row and saves back to the same bytes.
- The drawing rows are only offered under an On Draw event, because Godot refuses `draw_*` calls anywhere else. Redraw works anywhere: it asks the node to paint itself again, which runs On Draw.
- Rows that already existed for drawing on another node's canvas (Draw Line, Draw Circle, Draw Rect and the rest) are unchanged.
- A sentence can now carry a piece that shows only while its field has a value, so Draw Line reads "Draw line from a to b in red" and gains ", width 2" once a width is set.

### Fixed: the kind check no longer builds a broken test script from a match arm

- A `match` arm, an `elif` or an `else` that stayed in a code cell was handed to the kind check as if it were a statement of its own, which Godot cannot read, so a parse error was printed every time such a sheet opened and the lines judged after it in the same pass could go unchecked. Those cells are now left out of the check.
- A row whose code has an optional trailing argument (a width you may leave blank) no longer makes the same check print a parse error while you edit one of its fields.

### Changed: the two tick triggers read for what they are

- A `_process` event now reads **Every tick** and a `_physics_process` event reads **Every physics tick**. They used to read "Every tick (draw)" and "Every tick (physics)", and `_process` has nothing to do with drawing. Only the words changed: the trigger ids, the templates and the code a sheet compiles to are exactly what they were. The same words are used where a hand-written `set_process(false)` / `set_physics_process(false)` reads ("Set Every tick deactivated", "Set Every physics tick deactivated"), in the muted note on a conditionless physics tick, and in the Doctor's handler list.

### Fixed: `delta` reads as `delta`

- A row that says `Vector2(speed * delta, 0)` in the code used to read `Vector2(speed * dt, 0)` on the sheet. Rows now read your identifiers exactly as you wrote them, so `delta` stays `delta` everywhere (conditions, actions, expressions, a pack's rows). A bare `get_process_delta_time()` reads `delta` too, and a call on another object (`host.get_process_delta_time()`) keeps its own spelling.

### Changed: the README's player example is real Godot, and its four pictures show it

- The example in "What it compiles to" now takes its hits from an `Area2D` child named `Hitbox` whose `body_entered` signal is wired in the scene, because a `CharacterBody2D` has no `body_entered` signal of its own and the old `_on_body_entered` would never have run. The sheet reads that handler as a real **On collision with** trigger on the `Hitbox`, and the hit is `health -= 10`. The example and its `enemy` scene live in `demo/readme_example/`, the scene opens with "No problems", and the README's bullets use the words the editor shows.
- The workspace and Generated GDScript pictures (Default and Light themes) were retaken on that example at a comfortable editor zoom, so every word reads at the README's width.
- The mistake-check tests that pin the nearest group name to a typo now judge groups against their own fixtures only, so a group elsewhere in the project (the example's `enemy`) cannot change which name they offer.

## Releases

- **v0.20.0** (2026-11-07) - Feel Native
  This release makes the editor sit inside Godot like one of its own docks, and makes it sturdier after a heavy overhaul of how it looks and behaves. Nearly every window, row and menu was reworked to say plainly what it does, to work in Godot's light and dark themes, and to stay quick on big sheets. If your daily driver is Construct 3 or Godot, the picker, the sheet and the fields now answer to names you already know. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.20.0.md)

  **A look that belongs in Godot**

  - A new default look, Editor Native, that reads like Godot's own docks: variables listed the way the Inspector lists a property, blue condition lanes and green action lanes, and each event drawn as one panel with its nesting as lines in the margin.
  - Words, names and values sit in aligned columns, the parameter band hangs under a function's line, and sub-events pack tight under their parent.
  - It follows Godot's Light and Default editor themes from the moment the editor starts, keeps its toolbar words readable on any theme base, and switching the editor theme while a sheet is open re-colours the sheet with no restart.
  - A sheet opens on one thin head bar, the side panel rests as a rail, and every line leads with its icon instead of a word in front of it.

  **Familiar names, familiar flow**

  - Type a name from another engine or from Construct 3 and the picker finds the verb that already ships; expression fields read `Mathf.Lerp` and `Random.Range`.
  - The Welcome window asks how you usually make games and offers a first game you already know as a showcase with a ten-step tour.
  - Picking is offered in Godot's shape: write a condition on another object's sheet and the sheet offers the For each that goes with it.
  - Click a script in the FileSystem and its sheet opens, and the Manual opens on the page it names from nearly any row, window or menu.

  **Variables, functions and your own objects**

  - A variable's Inspector options each open as the variable they belong to, export groups read as boxes, and the variable window is four cards where every look is a described choice.
  - One Save choice per variable (Never, Auto, Load only, Save only, Manual), and values players already saved keep loading through a rename or an update.
  - Functions are drawn as events on every sheet and edited in Godot's own Inspector, with every choice described and a name that would break the script refused before it is written.
  - Shape a field in the Inspector Designer: groups as tabs, two fields side by side, a dropdown filled by a function, picking a table row by name, and search, sort and pages for big tables.
  - New behaviour and New global are forms you can reopen, Add behaviour is a shelf of tiles with your own first, New Data Table is filled in like a spreadsheet, and a script class is made like inserting an object.
  - An object's states work project-wide, with one state row that carries a default and a description for each state.
  - A project holds only the behaviours it asked for: the packs ship in a library folder Godot never imports, and adding one copies a folder.

  **Your own code opens as rows**

  - Functions written inside a call, classes inside a script, values over several lines and statements continued with `\` open as rows and save back byte-exact.
  - The plugin's own scripts open as rows too, with no block of code on screen.
  - Hand-written `.gd` scripts open as tidy, readable rows, and every way a `.gd` save used to drop something (disabled events, groups, regions, class descriptions) is closed.
  - Position rows say which space they mean: Set X / Y / Z read relative to the parent, and world twins sit beside them for setting, reading, spawning, wrapping, bounding and gliding.
  - New rows: Tell Children, First Parent Of Type, Next / Previous Sibling, Reset Variable(s), Pick First / Last Where, Has Been True For, and pause requests that keep the game paused until everyone who asked lets go.
  - New packs: Flock and Flock 3D (birds, fish and swarms that steer by their neighbours), and a Platformer Pathfinding that learns every way a character gets around.

  **Catching mistakes as you type**

  - Type checking in every field: Godot's own analyzer answers in a plain sentence plus its own words, underlines the exact span, and blocks OK on an error.
  - Autocomplete follows the code the way Godot's script editor does: dot completion through chains, argument hints, names inside quotes, and descriptions from the class reference.
  - Colour values show a square of the colour and read the way you typed them: click the square for Godot's own ColorPicker with no window in between, right-click it to Copy As hex, RGB, HSV or code, and pick how every colour reads with Read Colours As (your code never changes).
  - Nine mistakes Godot only reports when the game runs are caught on the row with a fix beside each, and a broken script marks its row with Godot's own words on save.
  - A run-time error in a `.gd` sheet or a hand-written script links to its row, in a game started from the editor, with nothing added to the game.

  **Studios and windows**

  - The Save studio gains file, slots, look-inside and player-settings tabs, and the Translation Studio reads as four steps, stays fast at a million lines, and never rewrites a catalog you wrote by hand.
  - Every dialog says what it will do before you press OK, opens at the size of what it holds, and reads in a light theme.
  - Renaming a variable shows everything it touches first, and project-wide find, replace and rename now see `.gd` sheets.
  - The MCP server edits `.gd` sheets, works through the open editor, and edits single rows.

  **Faster, and cleaner when it leaves**

  - The editor starts in about 11 seconds instead of 30, and the picker lists every pack verb (it showed 142 of 4,477).
  - Dropping a drag on an 803-row sheet takes about 0.75 s (it was 2.8 s), and a fold click on a large sheet is under 50 ms (it was about 0.5 s), and hover and drag repaint only the row they touch.
  - Disabling the plugin frees its whole workspace instead of leaving it in memory.

- **v0.18.0** (2026-09-06) - Refactor Anything, Render Anything & Feel Everything
  The refactor contract (moved verbs keep a forwarding address, Migrate proves every rewrite), states and scenes as rows, the render vocabulary and shape nodes, the Feedback Player, the gameplay systems, the resting toolbar and the Manual. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.18.0.md)
- **v0.17.0** (2026-08-17) - Adopt Anything, Read Anything & Ask Why
  Real `.gd` files open as rows byte-exact, your own classes become vocabulary, the pattern and developer-experience waves, and every guide readable inside the editor. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.17.0.md)
- **v0.16.0** (2026-07-28)
  Nine editor languages, the Custom Resource wizard, `publish_pack`, renamed verbs that keep working, parameters shaped by addon authors, and a full docs freshness sweep. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.16.0.md)
- **v0.15.0** (2026-07-13) - Save Anything, Control Anything & BBcode it
  The save-state seam on 18 packs, six save formats, the Save Studio and the ACE Studio, BBCode comments, and the player-or-AI input seam. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.15.0.md)
- **v0.14.0** (2026-07-12) - The Pathfinding & Game-Feel Update
  Platformer Pathfinding and Nav Agent 3D, the universal AI drive seam, FPS movement tech, Juice cameras, the Input Map picker and a much faster boot. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.14.0.md)
- **v0.13.0** (2026-07-08) - The Genre Toolkits Update
  The incremental / idle game suite, ECS-lite Systems, Loot Table and SkinVault, an object pool, Advanced Random behind one seed, and auto-registering pack builders. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.13.0.md)
- **v0.12.0** (2026-07-06) - The Inspector Designer Update
  The Inspector Designer with its drawers and custom resources, HUD Kit, Scene Flow and Dialogue Kit, sheets created from the FileSystem, and a lazily built editor. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.12.0.md)
- **v0.11.0** (2026-07-04) - The Structure & Vocabulary Update
  Regions, the Look Gallery, localisation vocabulary, Extract to Function, featured verbs, Teach a Verb and the public `EventSheets` API. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.11.0.md)
- **v0.10.0** (2026-07-04) - The In-Sheet Authoring Update
  In-sheet authoring: the ACE Studio, per-function shell-lift, Ghost Row, error-to-row, the complete Custom Block API, and a much faster editor open. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.10.0.md)
- **v0.9.5** (2026-06-29) - Code-Free Authoring & First-Class Variables
  Code-free authoring and first-class variables: `.gd` as the default sheet format, `@export` variables with Inspector drawers, drop a scene node onto a parameter, New Behaviour Addon. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.9.5.md)
- **v0.9.0** (2026-06-22) - Performance & Game Feel
  Frame-spreading performance, Juice game feel, and first-class UI, raycast, particle, tilemap and shader vocabulary, with a plain-language picker. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.9.0.md)
- **v0.8.0** (2026-06-20) - "The Team & Scale Update"
  Team and scale: a merge driver, Find References, an includes manager, HTN Agent, the Theme Editor's Quick Style, Godot 4.7 and byte-stable regeneration. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.8.0.md)
- **v0.7.0** (2026-06-12) - “The Native Workflow Update”
  Godot-native workflow: entry points, debug, docs and shortcuts like Godot, a first-run hook, and wider GDScript coverage for branching lifts. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.7.0.md)
- **v0.6.2** (2026-06-12)
  Project usability: compile-on-save, reviewable sheet diffs, the Project Doctor, the project vocabulary doc, sheet backups and one pack-builder file per pack. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.2.md)
- **v0.6.1** (2026-06-12)
  Hygiene after 0.6.0: a repo review sweep and the dock split into four extracted subsystems. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.1.md)
- **v0.6.0** (2026-06-12)
  Editable Live Values (the debugger, both directions), Save System v2, runtime groups, project-wide find, nested live values, a fuzzy picker and keyboard flow. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.0.md)
- **v0.5.0** (2026-06-12)
  Keyboard, Mouse, Gamepad and Touch vocabulary, the Audio module, a searchable scene-node picker, per-ACE comments and starter templates. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.5.0.md)
- **v0.4.0** (2026-06-10)
  Starter 3D vocabulary, find that reaches folded groups, five silent-bug fixes and CONTRIBUTING.md. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.4.0.md)
- **v0.3.0** (2026-06-10)
  Multi-view: split view, linked panes and detached windows, plus experimental tool sheets that build editor tooling from events. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.3.0.md)
- **v0.2.0** (2026-06-10)
  Native-node ACE providers, fourteen behavior packs, combo and color parameters, iconic theme presets and Export Addon Pack. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.2.0.md)
- **v0.1.0** (2026-05-15)
  The first public cut: the editor, the compiler and lossless pairing. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.1.0.md)
