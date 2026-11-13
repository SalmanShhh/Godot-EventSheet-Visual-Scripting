# Godot EventSheets - the project-level surfaces
#
# The project-level surfaces, one test, because they share one shape: a small pure table decides what the reader
# sees, and the UI is only a way to show it. Everything pinned here is a VALUE - the exact line an
# entry reads as, the exact route a double-click takes, the exact button set a mode offers, the exact
# bindings a preset writes - never a count, because a count passes for the wrong reasons.
@tool
class_name ProjectLevelUXTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The about comment Pin Modes opens with, quoted here so the cut is pinned on a real one.
const PIN_MODES_ABOUT: String = "[b]Pin Modes[/b] - six ways one object can ride another, running at once. The sheet moves only the ANCHORS (the post, the engine, the walker); everything else is a Pin behavior in a different mode."


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _visibility_rules() and all_passed
	all_passed = _toolbar_and_preview_buttons() and all_passed
	all_passed = _shortcut_preset() and all_passed
	all_passed = _start_page_columns() and all_passed
	all_passed = _start_page_lists_every_showcase() and all_passed
	return all_passed


static func _visibility_rules() -> bool:
	var all_passed: bool = true
	all_passed = _check("the Add toolbar follows Simple mode when nobody asked",
		EventSheetBeginnerToolbar.should_show(null, true), true) and all_passed
	all_passed = _check("the Add toolbar is off outside Simple mode",
		EventSheetBeginnerToolbar.should_show(null, false), false) and all_passed
	all_passed = _check("an explicit Add-toolbar choice wins",
		EventSheetBeginnerToolbar.should_show(true, false), true) and all_passed
	return all_passed


static func _toolbar_and_preview_buttons() -> bool:
	var all_passed: bool = true
	var ids: PackedStringArray = PackedStringArray()
	var labels: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetBeginnerToolbar.BUTTONS:
		ids.append(str((entry as Array)[0]))
		labels.append(str((entry as Array)[1]))
	all_passed = _check("the beginner toolbar is the eight Add gestures, in reading order",
		" ".join(labels),
		"+ Event + Sub-event + Condition + Action + Group + Comment + Variable + Function") and all_passed
	all_passed = _check("and they are the eight ids the dock dispatches",
		" ".join(ids),
		"add_event add_sub_event add_condition add_action add_group add_comment add_variable add_function") and all_passed
	# Each button teaches the key it stands in for, which is what makes the strip temporary.
	all_passed = _check("a button names its key on hover",
		EventSheetBeginnerToolbar.tooltip_for("add_event"),
		"Start a new event.  (E)") and all_passed
	all_passed = _check("a function is added with F",
		EventSheetShortcuts.binding_for("add_function"), "F") and all_passed
	var preview_ids: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetRunControls.BUTTONS:
		preview_ids.append(str((entry as Array)[0]))
	# UPDATED WITH THE PLAY BUTTON: the table used to hold the four Preview gestures the sheet's own
	# strip offered, and Run Scene and Play as host + client were two hand-written toolbar buttons
	# beside it. There is one table now, six entries, and it is read by the play button's face, the
	# play button's dropdown and the expanded strip's buttons alike - so the order below IS the order
	# the dropdown lists, four the sheet owns and then Godot's own two.
	all_passed = _check("the six ways to play, in the order the play button lists them",
		" ".join(preview_ids),
		"run_scene debug_layout run_profiler host_client preview_layout preview_project") and all_passed
	all_passed = _check("and the last two are marked as Godot's own keys under familiar names",
		" ".join(EventSheetRunControls.GODOT_OWN), "preview_layout preview_project") and all_passed
	all_passed = _check("the profiler run keeps its name while a game is running - it is not a stop button",
		EventSheetRunControls.label_for("run_profiler", true), "⏱ Run with profiler") and all_passed
	all_passed = _check("Preview scene says what it does while nothing is running",
		EventSheetRunControls.label_for("preview_layout", false), "▶ Preview scene") and all_passed
	all_passed = _check("Preview project becomes Restart",
		EventSheetRunControls.label_for("preview_project", true), "↻ Restart") and all_passed
	all_passed = _check("Debug scene keeps its name - it is not a stop button",
		EventSheetRunControls.label_for("debug_layout", true), "🐞 Debug scene") and all_passed
	all_passed = _check("Preview scene is on Godot's own run-this-scene key",
		EventSheetShortcuts.binding_for("preview_layout"), "F6") and all_passed
	all_passed = _check("Preview project is on Godot's run-the-game key",
		EventSheetShortcuts.binding_for("preview_project"), "F5") and all_passed
	return all_passed


static func _shortcut_preset() -> bool:
	var all_passed: bool = true
	all_passed = _check("the picker offers two presets",
		" ".join(PackedStringArray(EventSheetShortcuts.PRESET_ORDER)),
		"eventsheets another_editor") and all_passed
	all_passed = _check("and names the second one without naming a product",
		EventSheetShortcuts.preset_label_for("another_editor"),
		"Another event-sheet editor") and all_passed
	all_passed = _check("with nothing applied the default preset is the live one",
		EventSheetShortcuts.active_preset(), "eventsheets") and all_passed
	EventSheetShortcuts.apply_preset("another_editor")
	# The preset rebinds ONLY what differs: E / S / C / A / G / Q / V / B already match, so they are
	# not in the table at all and must come through untouched.
	all_passed = _check("invert moves to the key the other editor uses",
		EventSheetShortcuts.binding_for("invert_condition"), "X") and all_passed
	all_passed = _check("collapse / expand lands on Ctrl+E",
		EventSheetShortcuts.binding_for("toggle_collapse"), "Ctrl+E") and all_passed
	all_passed = _check("so the Ctrl alternate for add-event steps aside",
		EventSheetShortcuts.binding_for("add_event_chord"), "") and all_passed
	all_passed = _check("preview moves to F4",
		EventSheetShortcuts.binding_for("preview_layout"), "F4") and all_passed
	all_passed = _check("adding an event is still E - the preset never touched it",
		EventSheetShortcuts.binding_for("add_event"), "E") and all_passed
	all_passed = _check("and the picker now reads back the preset that is in force",
		EventSheetShortcuts.active_preset(), "another_editor") and all_passed
	# Everything stays rebindable: one key changed by hand and the dialog stops claiming the preset.
	EventSheetShortcuts.set_binding("invert_condition", "Ctrl+Alt+I")
	all_passed = _check("a hand-rebound key drops the picker back to the default preset",
		EventSheetShortcuts.active_preset(), "eventsheets") and all_passed
	EventSheetShortcuts.apply_preset("eventsheets")
	all_passed = _check("the default preset puts every key back",
		EventSheetShortcuts.binding_for("invert_condition"), "I") and all_passed
	all_passed = _check("including the Ctrl alternate the other preset had cleared",
		EventSheetShortcuts.binding_for("add_event_chord"), "Ctrl+E") and all_passed
	return all_passed


## The Start page's three columns, read through `columns` with no window. The template column
## leads with the reader's own project ("Open an existing script…"), then every starter of the
## New-Sheet menu by shelf - 3D, menus and autoloads included - each row carrying its kind beside
## its name and its pitch for the help strip, then the showcases.
## The first row of `shelf` in the template column, as "label · kind · target".
static func _first_on(templates: Array, shelf: String) -> String:
	for entry: Variant in templates:
		var row: Dictionary = entry as Dictionary
		if str(row.get("shelf", "")) == shelf:
			return " · ".join([str(row.get("label", "")), str(row.get("kind", "")), str(row.get("target", ""))])
	return ""


## The shelf of each run of rows, in order - the headings the list draws, one per shelf change.
static func _shelf_runs(templates: Array) -> PackedStringArray:
	var runs: PackedStringArray = PackedStringArray()
	for entry: Variant in templates:
		var shelf: String = str((entry as Dictionary).get("shelf", ""))
		if runs.is_empty() or runs[runs.size() - 1] != shelf:
			runs.append(shelf)
	return runs


static func _start_page_columns() -> bool:
	var columns: Array = EventSheetStartPage.columns(PackedStringArray(["starfall"]), ["res://player.gd"])
	var titles: PackedStringArray = PackedStringArray()
	for column: Variant in columns:
		titles.append(str((column as Dictionary).get("title", "")))
	var templates: Array = (columns[0] as Dictionary).get("entries", [])
	var by_label: Dictionary = {}
	for entry: Variant in templates:
		by_label[str((entry as Dictionary).get("label", ""))] = entry
	var recent: Array = (columns[1] as Dictionary).get("entries", [])
	var learn: Array = (columns[2] as Dictionary).get("entries", [])
	var behaviour: Dictionary = by_label.get("Behavior Component", {})
	return SUPPORT.pins("start_page_columns", [
		["the Start page is three columns", " | ".join(titles), "New from template | Recent | Learn"],
		["opening an existing script comes first",
			[str((templates[0] as Dictionary).get("label", "")), str((templates[0] as Dictionary).get("kind", ""))],
			["Open an existing script…", "open_script"]],
		["the shelves read in the menu's order, the reader's own project first",
			" | ".join(EventSheetStartPage.shelves(templates)),
			"Your project | 2D | 3D | UI and menus | Behaviours | Project-wide (autoloads) | Game shapes | Data | Editor tools | Showcases"],
		["each shelf is one run, so no heading is drawn twice", " | ".join(_shelf_runs(templates)),
			"Your project | 2D | 3D | UI and menus | Behaviours | Project-wide (autoloads) | Game shapes | Data | Editor tools | Showcases"],
		["the 3D starters are on the page",
			[str((by_label.get("First-Person Controller", {}) as Dictionary).get("shelf", "")),
				str((by_label.get("Keycard Door", {}) as Dictionary).get("tag", ""))],
			["3D", "Doors"]],
		["a starter row is its name and its kind, the parenthesis dropped",
			[str(behaviour.get("label", "")), str(behaviour.get("tag", ""))], ["Behavior Component", "Behaviour"]],
		["its pitch is the help strip's line", str(behaviour.get("pitch", "")),
			"One behavior you attach to any node: signals in, actions out, nothing else to set up."],
		["and the strip says what Open does with it", EventSheetStartPage.opens_line(behaviour),
			"Behavior Component as a new unsaved sheet - Save As… keeps it."],
		["the Systems starter is offered", str((by_label.get("Entity System", {}) as Dictionary).get("tag", "")), "System"],
		# The Behaviours and Project-wide shelves each open on the form that makes one of your own.
		["the Behaviours shelf leads with New behaviour…", _first_on(templates, "Behaviours"), "New behaviour… · maker · behaviour"],
		["the Project-wide shelf with New global…", _first_on(templates, "Project-wide (autoloads)"), "New global… · maker · global"],
		["and the strip says which form opens", EventSheetStartPage.opens_line(by_label.get("New global…", {})), "The New global form."],
		["a showcase sits in the same column, on its genre",
			[str((templates[templates.size() - 1] as Dictionary).get("label", "")),
				str((templates[templates.size() - 1] as Dictionary).get("tag", "")),
				str((templates[templates.size() - 1] as Dictionary).get("pitch", ""))],
			["Starfall", "Arcade", "Falling objects, a score and a fail state - the whole loop in one small scene."]],
		["Recent is what you had open, by file", str((recent[0] as Dictionary).get("label", "")), "player.gd"],
		["Learn leads with the first tutorial", str((learn[0] as Dictionary).get("label", "")), "Your first event"],
		["and ends with What's new", str((learn[learn.size() - 1] as Dictionary).get("label", "")), "What's new"],
		# A showcase opens its own scene, not the last scene of the folder by name.
		["a showcase opens the scene named after its folder",
			EventSheetStartPage.showcase_scene("res://demo/showcase/platformer_shooter"),
			"res://demo/showcase/platformer_shooter/platformer_shooter.tscn"],
		["a showcase_<folder> scene counts as the folder's own",
			EventSheetStartPage.showcase_scene("res://demo/showcase/carousel"),
			"res://demo/showcase/carousel/showcase_carousel.tscn"],
	])


## The Start page walks demo/showcase, so a showcase added by the example builder appears on it
## with no list to edit. The one thing the page still writes down is the shelf a showcase sits on -
## nothing in a showcase says which genre a reader looks for it under - so that is the one thing a
## new showcase can leave behind, and these two pins are what name it: the folders with no shelf,
## and the shelves whose folder is gone. Both are pinned as the NAMES, joined, so a red run says
## which showcase rather than how many.
##
## The line on the card comes from the showcase itself: the about comment its sheet opens with, cut
## down to its first clause. The cut is pinned on the three shapes those comments take - a sentence,
## a colon introducing a list, and an "and" opening a second clause - and then end to end through
## `columns`, where a pitch still written on the page beats the showcase's own line.
static func _start_page_lists_every_showcase() -> bool:
	var derived: Array = EventSheetStartPage.columns(PackedStringArray(["pin_modes"]), [],
		false, {"pin_modes": PIN_MODES_ABOUT})
	var written: Array = EventSheetStartPage.columns(PackedStringArray(["starfall"]), [],
		false, {"starfall": "[b]Starfall[/b] - a complete restartable arcade game authored as events: move the ship."})
	var silent: Array = EventSheetStartPage.columns(PackedStringArray(["a_new_showcase"]),
		[], false, {})
	return SUPPORT.pins("start_page_showcases", [
		["every showcase folder has a shelf on the page",
			" | ".join(EventSheetStartPage.showcases_without_a_shelf()), ""],
		["and every shelf on the page names a folder that is there",
			" | ".join(EventSheetStartPage.shelves_without_a_showcase()), ""],
		["a sentence in an about comment is the card's line",
			EventSheetStartPage.pitch_from_about(PIN_MODES_ABOUT),
			"Six ways one object can ride another, running at once."],
		["a colon introducing a list ends it instead",
			EventSheetStartPage.pitch_from_about("[b]EnemyStats[/b] - a Custom Resource whose Inspector was [b]designed from this sheet[/b]: accent section headers, an info note, a required portrait slot."),
			"A Custom Resource whose Inspector was designed from this sheet."],
		["and so does the \"and\" that opens a second clause",
			EventSheetStartPage.pitch_from_about("[b]Mirror Hero[/b] - one row faces the way it moves, and because it mirrors the WHOLE object every child comes along."),
			"One row faces the way it moves."],
		["a showcase with no about comment says nothing rather than something wrong",
			EventSheetStartPage.pitch_from_about(""), ""],
		["the new Platformer Pathfinding showcase reads its line off its own sheet",
			EventSheetStartPage.pitch_from_about(
				EventSheetStartPage.showcase_about("platformer_pathfinding")),
			"The smallest chaser the pack can make."],
		["a card carries the shelf and the showcase's own line",
			_showcase_note(derived), "Toy · Six ways one object can ride another, running at once."],
		["a pitch still written on the page beats the showcase's own line",
			_showcase_note(written),
			"Arcade · Falling objects, a score and a fail state - the whole loop in one small scene."],
		["and a folder the page knows nothing about is still a card",
			_showcase_note(silent),
			"Showcase · A playable example you can open and take apart."],
	])


## The note on the one showcase card in a New from template column.
static func _showcase_note(built: Array) -> String:
	for entry: Variant in (built[0] as Dictionary).get("entries", []):
		if str((entry as Dictionary).get("kind", "")) == "showcase":
			return "%s · %s" % [str((entry as Dictionary).get("tag", "")), str((entry as Dictionary).get("pitch", ""))]
	return "no showcase card was built"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] %s" % label)
		return true
	print("[FAIL] %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
