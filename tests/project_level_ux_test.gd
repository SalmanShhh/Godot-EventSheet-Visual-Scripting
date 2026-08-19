# Godot EventSheets - the project-level surfaces (T13 / T14 / T15 / T18 / T19)
#
# Five surfaces, one test, because they share one shape: a small pure table decides what the reader
# sees, and the UI is only a way to show it. Everything pinned here is a VALUE - the exact line an
# entry reads as, the exact route a double-click takes, the exact button set a mode offers, the exact
# bindings a preset writes - never a count, because a count passes for the wrong reasons.
@tool
class_name ProjectLevelUXTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _outline_reads_by_kind() and all_passed
	all_passed = _headings_follow_familiar_words() and all_passed
	all_passed = _routes_and_drags() and all_passed
	all_passed = _doctor_badges() and all_passed
	all_passed = _visibility_rules() and all_passed
	all_passed = _toolbar_and_preview_buttons() and all_passed
	all_passed = _shortcut_preset() and all_passed
	all_passed = _start_page_columns() and all_passed
	return all_passed


## A fixture project, as the scan would hand it over: two scenes, three scripts (one of them an
## autoload), two declared classes where one extends the other, one pack, one sound, some art.
static func _fixture_scan() -> Dictionary:
	return {
		"scenes": PackedStringArray(["res://main_menu.tscn", "res://level_1.tscn"]),
		"scripts": PackedStringArray(["res://player.gd", "res://slime.gd", "res://game.gd"]),
		"sounds": PackedStringArray(["res://audio/jump.ogg"]),
		"others": PackedStringArray(["res://art/hero.png", "res://art/tiles.png", "res://data/levels.json"]),
		"classes": [
			{"name": "Player", "path": "res://player.gd", "base": "CharacterBody2D"},
			{"name": "Slime", "path": "res://slime.gd", "base": "Player"},
		],
		"autoloads": {"Game": "res://game.gd"},
		"packs": PackedStringArray(["health"]),
	}


static func _outline_reads_by_kind() -> bool:
	var all_passed: bool = true
	var outline: Dictionary = EventSheetProjectOutline.outline_from(_fixture_scan())
	all_passed = _check("a scene reads by its name, with its file muted beside it",
		EventSheetProjectBar.entry_text((outline["scenes"] as Array)[0]),
		"Main Menu  main_menu.tscn") and all_passed
	all_passed = _check("a script that declares a class reads under the class name",
		EventSheetProjectBar.entry_text((outline["scripts"] as Array)[0]),
		"Player  player.gd") and all_passed
	all_passed = _check("an autoload reads under its singleton name and says so",
		EventSheetProjectBar.entry_text((outline["scripts"] as Array)[2]),
		"Game  autoload · game.gd") and all_passed
	all_passed = _check("a base class reads with the classes that extend it",
		EventSheetProjectBar.entry_text((outline["base_classes"] as Array)[0]),
		"Player  Slime") and all_passed
	all_passed = _check("only a class something else extends is a base class",
		(outline["base_classes"] as Array).size(), 1) and all_passed
	all_passed = _check("an installed pack is a behavior",
		EventSheetProjectBar.entry_text((outline["behaviors"] as Array)[0]),
		"Health  health") and all_passed
	all_passed = _check("a sound reads by its name",
		EventSheetProjectBar.entry_text((outline["sounds"] as Array)[0]),
		"Jump  jump.ogg") and all_passed
	# FILES is folders, not files: the section says "there is also art and data over there", it does
	# not become a second FileSystem dock.
	all_passed = _check("files are folders with a count, not a file list",
		EventSheetProjectBar.entry_text((outline["files"] as Array)[0]),
		"art  2 files") and all_passed
	all_passed = _check("a folder with one thing in it says so in the singular",
		EventSheetProjectBar.entry_text((outline["files"] as Array)[1]),
		"data  1 file") and all_passed
	var covered: Dictionary = EventSheetProjectOutline.outline_from(
		_fixture_scan(), {"res://player.gd": "82% reads as events, 3 script blocks"})
	all_passed = _check("an open sheet's coverage rides the script's own line",
		EventSheetProjectBar.entry_text((covered["scripts"] as Array)[0]),
		"Player  player.gd · 82% reads as events, 3 script blocks") and all_passed
	all_passed = _check("the filter matches the note as well as the name",
		EventSheetProjectOutline.matches_filter((outline["scenes"] as Array)[1], "tscn"), true) and all_passed
	all_passed = _check("a filter that matches nothing says so",
		EventSheetProjectOutline.matches_filter((outline["scenes"] as Array)[1], "zzz"), false) and all_passed
	return all_passed


static func _headings_follow_familiar_words() -> bool:
	var all_passed: bool = true
	all_passed = _check("Godot's word leads with the other editor's beside it",
		EventSheetProjectOutline.heading_for("scenes", false), "Scenes  (layouts)") and all_passed
	all_passed = _check("Familiar Words swaps which one leads",
		EventSheetProjectOutline.heading_for("scenes", true), "Layouts  (scenes)") and all_passed
	all_passed = _check("scripts are event sheets in the other editor's words",
		EventSheetProjectOutline.heading_for("scripts", true), "Event sheets  (scripts)") and all_passed
	all_passed = _check("classes are object types",
		EventSheetProjectOutline.heading_for("classes", true), "Object types  (classes)") and all_passed
	all_passed = _check("base classes are families",
		EventSheetProjectOutline.heading_for("base_classes", false), "Base classes  (families)") and all_passed
	# A word both editors use is not dressed up as a translation of itself.
	all_passed = _check("a word both editors share stands alone",
		EventSheetProjectOutline.heading_for("sounds", true), "Sounds") and all_passed
	return all_passed


static func _routes_and_drags() -> bool:
	var all_passed: bool = true
	var outline: Dictionary = EventSheetProjectOutline.outline_from(_fixture_scan())
	all_passed = _check("a scene opens in the scene editor",
		EventSheetProjectOutline.route_for((outline["scenes"] as Array)[0]), "scene_editor") and all_passed
	all_passed = _check("a script opens as a sheet by default",
		EventSheetProjectOutline.route_for((outline["scripts"] as Array)[0], true), "sheet") and all_passed
	all_passed = _check("a script opens in the script editor when that is the reader's default",
		EventSheetProjectOutline.route_for((outline["scripts"] as Array)[0], false), "script_editor") and all_passed
	all_passed = _check("a class opens Object properties",
		EventSheetProjectOutline.route_for((outline["classes"] as Array)[0]), "object_properties") and all_passed
	all_passed = _check("a behavior opens its pack's reference page",
		EventSheetProjectOutline.route_for((outline["behaviors"] as Array)[0]), "pack_reference") and all_passed
	all_passed = _check("a sound has nowhere of its own to open, so it is shown where it lives",
		EventSheetProjectOutline.route_for((outline["sounds"] as Array)[0]), "file_system") and all_passed
	all_passed = _check("dragging a class starts an event on it",
		EventSheetProjectOutline.drag_intent_for((outline["classes"] as Array)[0]), "start_event") and all_passed
	all_passed = _check("dragging a sound is a Play sound action",
		EventSheetProjectOutline.drag_intent_for((outline["sounds"] as Array)[0]), "play_sound") and all_passed
	all_passed = _check("dragging a scene is a Go to layout action",
		EventSheetProjectOutline.drag_intent_for((outline["scenes"] as Array)[0]), "go_to_layout") and all_passed
	all_passed = _check("an entry the sheet has no gesture for refuses the drag",
		EventSheetProjectOutline.drag_intent_for((outline["files"] as Array)[0]), "") and all_passed
	return all_passed


static func _doctor_badges() -> bool:
	var all_passed: bool = true
	var findings: Array = [
		{"severity": "error", "check": "x", "path": "res://player.gd", "message": "boom"},
		{"severity": "warning", "check": "y", "path": "res://slime.gd", "message": "hmm"},
		{"severity": "info", "check": "z", "path": "res://game.gd", "message": "note"},
	]
	var badges: Dictionary = EventSheetProjectOutline.badge_map(findings)
	all_passed = _check("an error is counted against its file",
		int((badges["res://player.gd"] as Dictionary)["errors"]), 1) and all_passed
	all_passed = _check("a warning is counted apart from an error",
		int((badges["res://slime.gd"] as Dictionary)["warnings"]), 1) and all_passed
	EventSheetProjectOutline.set_doctor_findings(findings)
	all_passed = _check("a file with an error wears the error mark",
		EventSheetProjectOutline.badge_for({"path": "res://player.gd"}), "●") and all_passed
	all_passed = _check("a file with only a warning wears the warning mark",
		EventSheetProjectOutline.badge_for({"path": "res://slime.gd"}), "▲") and all_passed
	all_passed = _check("an info finding is not a badge",
		EventSheetProjectOutline.badge_for({"path": "res://game.gd"}), "") and all_passed
	all_passed = _check("a file the Doctor said nothing about wears nothing",
		EventSheetProjectOutline.badge_for({"path": "res://level_1.tscn"}), "") and all_passed
	EventSheetProjectOutline.clear_doctor_findings()
	all_passed = _check("clearing the findings clears the badges",
		EventSheetProjectOutline.badge_for({"path": "res://player.gd"}), "") and all_passed
	return all_passed


static func _visibility_rules() -> bool:
	var all_passed: bool = true
	all_passed = _check("nobody asked, nothing special: the Project bar stays off",
		EventSheetProjectBarGlue.should_show(null, false, false), false) and all_passed
	all_passed = _check("Simple mode turns the Project bar on",
		EventSheetProjectBarGlue.should_show(null, true, false), true) and all_passed
	all_passed = _check("a project started from a template turns it on too",
		EventSheetProjectBarGlue.should_show(null, false, true), true) and all_passed
	all_passed = _check("an explicit no wins over Simple mode",
		EventSheetProjectBarGlue.should_show(false, true, true), false) and all_passed
	all_passed = _check("an explicit yes wins over everything being off",
		EventSheetProjectBarGlue.should_show(true, false, false), true) and all_passed
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
	all_passed = _check("the sheet offers three Preview gestures",
		" ".join(preview_ids), "preview_layout preview_project debug_layout") and all_passed
	all_passed = _check("Preview layout says what it does while nothing is running",
		EventSheetRunControls.label_for("preview_layout", false), "▶ Preview layout") and all_passed
	all_passed = _check("and becomes Stop once a game is",
		EventSheetRunControls.label_for("preview_layout", true), "■ Stop") and all_passed
	all_passed = _check("Preview project becomes Restart",
		EventSheetRunControls.label_for("preview_project", true), "↻ Restart") and all_passed
	all_passed = _check("Debug layout keeps its name - it is not a stop button",
		EventSheetRunControls.label_for("debug_layout", true), "🐞 Debug layout") and all_passed
	all_passed = _check("Preview layout is on Godot's own run-this-scene key",
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


static func _start_page_columns() -> bool:
	var all_passed: bool = true
	var starters: Array = [{"id": 0, "label": "Blank Sheet"}, {"id": 1, "label": "Platformer Starter"}]
	var columns: Array = EventSheetStartPage.columns(
		starters, PackedStringArray(["starfall"]), ["res://player.gd"])
	var titles: PackedStringArray = PackedStringArray()
	for column: Variant in columns:
		titles.append(str((column as Dictionary).get("title", "")))
	all_passed = _check("the Start page is three columns",
		" | ".join(titles), "New from template | Recent | Learn") and all_passed
	var templates: Array = (columns[0] as Dictionary).get("entries", [])
	# The label comes from the starter table, so a renamed starter renames here too; the pitch and
	# the genre are the page's own.
	all_passed = _check("a starter carries its genre and its one-line pitch",
		"%s - %s" % [str((templates[0] as Dictionary).get("label", "")),
			str((templates[0] as Dictionary).get("note", ""))],
		"Platformer Starter - Platformer · Run, jump and coyote time, already wired - a character that feels right on the first run.") and all_passed
	all_passed = _check("a showcase sits in the same column, by genre",
		"%s - %s" % [str((templates[2] as Dictionary).get("label", "")),
			str((templates[2] as Dictionary).get("note", ""))],
		"Starfall - Arcade · Falling objects, a score and a fail state - the whole loop in one small scene.") and all_passed
	var recent: Array = (columns[1] as Dictionary).get("entries", [])
	all_passed = _check("Recent is what you had open, by file",
		str((recent[0] as Dictionary).get("label", "")), "player.gd") and all_passed
	var learn: Array = (columns[2] as Dictionary).get("entries", [])
	all_passed = _check("Learn leads with the first tutorial",
		str((learn[0] as Dictionary).get("label", "")), "Your first event") and all_passed
	all_passed = _check("and ends with What's new",
		str((learn[learn.size() - 1] as Dictionary).get("label", "")), "What's new") and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] %s" % label)
		return true
	print("[FAIL] %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
