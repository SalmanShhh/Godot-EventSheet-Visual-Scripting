# v0.20.0 - Feel Native

This release makes the editor sit inside Godot like one of its own docks, and makes it sturdier after a heavy overhaul of how it looks and behaves. Nearly every window, row and menu was reworked to say plainly what it does, to work in Godot's light and dark themes, and to stay quick on big sheets. If your daily driver is Construct 3 or Godot, the picker, the sheet and the fields now answer to names you already know.

## A look that belongs in Godot

- A new default look, Editor Native, that reads like Godot's own docks: variables listed the way the Inspector lists a property, blue condition lanes and green action lanes, and each event drawn as one panel with its nesting as lines in the margin.
- Words, names and values sit in aligned columns, the parameter band hangs under a function's line, and sub-events pack tight under their parent.
- It follows Godot's Light and Default editor themes from the moment the editor starts, keeps its toolbar words readable on any theme base, and switching the editor theme while a sheet is open re-colours the sheet with no restart.
- A sheet opens on one thin head bar, the side panel rests as a rail, and every line leads with its icon instead of a word in front of it.

## Familiar names, familiar flow

- Type a name from another engine or from Construct 3 and the picker finds the verb that already ships; expression fields read `Mathf.Lerp` and `Random.Range`.
- The Welcome window asks how you usually make games and offers a first game you already know as a showcase with a ten-step tour.
- Picking is offered in Godot's shape: write a condition on another object's sheet and the sheet offers the For each that goes with it.
- Click a script in the FileSystem and its sheet opens, and the Manual opens on the page it names from nearly any row, window or menu.

## Variables, functions and your own objects

- A variable's Inspector options each open as the variable they belong to, export groups read as boxes, and the variable window is four cards where every look is a described choice.
- One Save choice per variable (Never, Auto, Load only, Save only, Manual), and values players already saved keep loading through a rename or an update.
- Functions are drawn as events on every sheet and edited in Godot's own Inspector, with every choice described and a name that would break the script refused before it is written.
- Shape a field in the Inspector Designer: groups as tabs, two fields side by side, a dropdown filled by a function, picking a table row by name, and search, sort and pages for big tables.
- New behaviour and New global are forms you can reopen, Add behaviour is a shelf of tiles with your own first, New Data Table is filled in like a spreadsheet, and a script class is made like inserting an object.
- An object's states work project-wide, with one state row that carries a default and a description for each state.
- A project holds only the behaviours it asked for: the packs ship in a library folder Godot never imports, and adding one copies a folder.

## Your own code opens as rows

- Functions written inside a call, classes inside a script, values over several lines and statements continued with `\` open as rows and save back byte-exact.
- The plugin's own scripts open as rows too, with no block of code on screen.
- Hand-written `.gd` scripts open as tidy, readable rows, and every way a `.gd` save used to drop something (disabled events, groups, regions, class descriptions) is closed.
- Position rows say which space they mean: Set X / Y / Z read relative to the parent, and world twins sit beside them for setting, reading, spawning, wrapping, bounding and gliding.
- New rows: Tell Children, First Parent Of Type, Next / Previous Sibling, Reset Variable(s), Pick First / Last Where, Has Been True For, and pause requests that keep the game paused until everyone who asked lets go.
- New packs: Flock and Flock 3D (birds, fish and swarms that steer by their neighbours), and a Platformer Pathfinding that learns every way a character gets around.

## Catching mistakes as you type

- Type checking in every field: Godot's own analyzer answers in a plain sentence plus its own words, underlines the exact span, and blocks OK on an error.
- Autocomplete follows the code the way Godot's script editor does: dot completion through chains, argument hints, names inside quotes, and descriptions from the class reference.
- Colour values show a square of the colour and read the way you typed them: click the square for Godot's own ColorPicker with no window in between, right-click it to Copy As hex, RGB, HSV or code, and pick how every colour reads with Read Colours As (your code never changes).
- Nine mistakes Godot only reports when the game runs are caught on the row with a fix beside each, and a broken script marks its row with Godot's own words on save.
- A run-time error in a `.gd` sheet or a hand-written script links to its row, in a game started from the editor, with nothing added to the game.

## Studios and windows

- The Save studio gains file, slots, look-inside and player-settings tabs, and the Translation Studio reads as four steps, stays fast at a million lines, and never rewrites a catalog you wrote by hand.
- Every dialog says what it will do before you press OK, opens at the size of what it holds, and reads in a light theme.
- Renaming a variable shows everything it touches first, and project-wide find, replace and rename now see `.gd` sheets.
- The MCP server edits `.gd` sheets, works through the open editor, and edits single rows.

## Faster, and cleaner when it leaves

- The editor starts in about 11 seconds instead of 30, and the picker lists every pack verb (it showed 142 of 4,477).
- Dropping a drag on an 803-row sheet takes about 0.75 s (it was 2.8 s), and a fold click on a large sheet is under 50 ms (it was about 0.5 s), and hover and drag repaint only the row they touch.
- Disabling the plugin frees its whole workspace instead of leaving it in memory.
