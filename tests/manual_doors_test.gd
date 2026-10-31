# EventSheet - the ways into the Manual, and the pages they land on.
#
# Every door here is pinned by the page id it asks for, because a door that asked for a spelling the
# Manual does not know used to land on the home page and say "No documentation for that row" - which
# is what Menu > What's new and the Start page's What's new both did. What a door looks like in the
# real editor (the window, the dock, the click) is proven by driving the editor itself; this file
# pins the answers those clicks are built on.
@tool
class_name ManualDoorsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "manual_doors_test"
const FIXTURE_ROOT := "user://manual_doors_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_whats_new() and all_passed
	all_passed = _test_said_where() and all_passed
	all_passed = _test_doctor_learn_more() and all_passed
	all_passed = _test_section_help() and all_passed
	all_passed = _test_focus_after_close() and all_passed
	all_passed = _test_read_the_guide() and all_passed
	all_passed = _test_home_page() and all_passed
	all_passed = _test_pictures() and all_passed
	all_passed = _test_library_page() and all_passed
	all_passed = _test_view_switch() and all_passed
	all_passed = _test_manual_beside() and all_passed
	return all_passed


## Menu > What's new and the Start page's What's new ask for the page the router knows.
static func _test_whats_new() -> bool:
	var learn: Array = []
	for column: Dictionary in EventSheetStartPage.columns(PackedStringArray(), [], false, {}):
		if str(column.get("id", "")) == "learn":
			learn = column.get("entries", []) as Array
	var start_target: String = ""
	for entry: Dictionary in learn:
		if str(entry.get("label", "")) == "What's new":
			start_target = str(entry.get("target", ""))
	return SUPPORT.pins(NAME, [
		["the What's new id", EventSheetDocReference.whats_new_id(), "reference:whatsnew"],
		["Menu > What's new asks for it", EventSheetMenuBar.menu_doc_id(EventSheetMenuBar.MENU_WHATS_NEW_ID), "reference:whatsnew"],
		["Menu > Manual names no page of its own (it opens the last page read)",
			EventSheetMenuBar.menu_doc_id(EventSheetMenuBar.MENU_MANUAL_ID), ""],
		["Alt+Left walks back along the Manual's trail", EventSheetDocBrowser.trail_step(_key(KEY_LEFT, true)), -1],
		["Alt+Right walks forward", EventSheetDocBrowser.trail_step(_key(KEY_RIGHT, true)), 1],
		["a plain Left is the tree's", EventSheetDocBrowser.trail_step(_key(KEY_LEFT, false)), 0],
		["Start page > Learn > What's new asks for it", start_target, "reference:whatsnew"],
		["the router draws it", bool(EventSheetDocExplain.resolve(start_target).get("valid", false)), true],
		["as the What's new kind", str(EventSheetDocExplain.resolve(start_target).get("reference_kind", "")), "whatsnew"],
	])


## The status line says where a page really opened.
static func _test_said_where() -> bool:
	return SUPPORT.pins(NAME, [
		["a shipped guide opens inside", EventSheetDocExplain.opens_inside("guide:GUIDE-RECIPES"), true],
		["a page that does not exist opens nowhere", EventSheetDocExplain.opens_inside("guide:NO-SUCH-PAGE"), false],
		["inside, said as the Manual", EventSheetDocExplain.opened_line("the Platformer guide", true),
			"Opened the Platformer guide in the Manual."],
		["outside, said as the browser", EventSheetDocExplain.opened_line("the Platformer guide", false),
			"Opened the Platformer guide in your browser."],
	])


## A finding's Learn more lands on the heading over the first mention of its check.
static func _test_doctor_learn_more() -> bool:
	var pages: Dictionary = {
		"B-GUIDE": "# Second\n\n## Where it hides\n\nThe `fragile-node-path` check reads this.\n",
		"A-GUIDE": "# First\n\n## Paths\n\nA fragile-node-paths word is not the check.\n\n```\nfragile-node-path\n```\n",
	}
	return SUPPORT.pins(NAME, [
		["the page that names the check, at its heading",
			EventSheetProjectDoctorPanel.learn_more_for({"check": "fragile-node-path"}, pages),
			{"doc_id": "guide:B-GUIDE", "anchor": "where-it-hides", "title": "Second · Where it hides"}],
		["a check no page names has no Learn more",
			EventSheetProjectDoctorPanel.learn_more_for({"check": "never-mentioned"}, pages), {}],
		["a finding with no check has none", EventSheetProjectDoctorPanel.learn_more_for({}, pages), {}],
		["a one-word check is not named by the plain word in prose",
			EventSheetProjectDoctorPanel.learn_more_for({"check": "collisions"},
				{"C-GUIDE": "# Third\n\n## Hits\n\nSome collisions happen.\n"}), {}],
		["a guide's own Doctor section answers for its subject",
			EventSheetProjectDoctorPanel.learn_more_for({"check": "collisions"},
				{"E-GUIDE": "# Collisions - What Touches What\n\n## Shapes\n\n## What the Doctor checks\n"}),
			{"doc_id": "guide:E-GUIDE", "anchor": "what-the-doctor-checks", "title": "Collisions - What Touches What · What the Doctor checks"}],
		["but is named by its spelling as code",
			str(EventSheetProjectDoctorPanel.learn_more_for({"check": "collisions"},
				{"C-GUIDE": "# Third\n\n## Hits\n\nThe `collisions` check.\n"}).get("anchor", "")), "hits"],
		["the shipped Manual explains region-fence",
			str(EventSheetProjectDoctorPanel.learn_more_for({"check": "region-fence"}).get("doc_id", "")),
			"guide:GUIDE-VARIABLES-GROUPS-AND-THE-SHEET-HEAD"],
	])


## A picker section heading's "?" opens the vocabulary module page for that group of words.
static func _test_section_help() -> bool:
	return SUPPORT.pins(NAME, [
		["Time opens its module page", ACEPickerDialog.section_doc_id("Time"), "module:Time"],
		["a sub-section asks for its own page first", ACEPickerDialog.section_doc_id("Variables: Array"), "module:Variables: Array"],
		["the module page is drawn inside", EventSheetDocExplain.opens_inside(ACEPickerDialog.section_doc_id("Time")), true],
		["a heading with no page has no ?", ACEPickerDialog.section_doc_id("No Such Words"), ""],
		["a behaviour's heading opens its guide", ACEPickerDialog.section_doc_id("FPS Controller"), "guide:Addons/FPS-Controller"],
	])


## Closing the Manual hands the focus back to the window it opened over (the picker, after a section
## "?"), so the picker's next click lands; a window that has gone, or the Manual itself, gets nothing.
static func _test_focus_after_close() -> bool:
	var manual: Window = Window.new()
	var picker: Window = Window.new()
	picker.visible = true
	var hidden: Window = Window.new()
	hidden.visible = false
	var rows: Array = [
		["the picker it opened over gets the focus back", EventSheetDocWindow.focus_after_close(picker, manual) == picker, true],
		["no opener, no hand-back", EventSheetDocWindow.focus_after_close(null, manual) == null, true],
		["a closed opener gets nothing", EventSheetDocWindow.focus_after_close(hidden, manual) == null, true],
		["the Manual never hands the focus to itself", EventSheetDocWindow.focus_after_close(manual, manual) == null, true],
	]
	manual.free()
	picker.free()
	hidden.free()
	return SUPPORT.pins(NAME, rows)


## Add behaviour's Read the guide, for a pack in the project and one waiting in the library.
static func _test_read_the_guide() -> bool:
	return SUPPORT.pins(NAME, [
		["a project pack reads its shipped guide", EventSheetAddBehaviorDialog.guide_doc_id({"dir": "platformer"}), "guide:Addons/Platformer"],
		["a library pack reads the same guide", EventSheetAddBehaviorDialog.guide_doc_id({"dir": "platformer", "state": "library"}), "guide:Addons/Platformer"],
		["a pack with no guide has no link", EventSheetAddBehaviorDialog.guide_doc_id({"dir": "no_such_pack", "state": "library"}), ""],
	])


## The home page: Start here, Look something up, and the line for people moving across.
static func _test_home_page() -> bool:
	var headings: Array = []
	var labels: Array = []
	for block: Dictionary in EventSheetDocReference.home_blocks():
		if str(block.get("kind", "")) == "heading":
			headings.append(str(block.get("text", "")))
		if str(block.get("kind", "")) == "buttons":
			for item: Dictionary in (block.get("items", []) as Array):
				labels.append(str(item.get("label", "")))
	var titles: Array = []
	for group: Dictionary in EventSheetDocLibrary.groups():
		titles.append(str(group.get("title", "")))
	return SUPPORT.pins(NAME, [
		["the home page's headings", headings, ["Documentation index", "Start here", "Look something up",
			"Coming from another event-sheet editor"]],
		["its doors", labels, ["Your first platformer", "A top-down shooter", "What's new", "Learning paths",
			"Every condition and action", "Every behaviour", "Glossary", "Patterns", "Moving from another event-sheet editor"]],
		["the contents group is named for the reader, not a product", titles.has("Coming from another event-sheet editor"), true],
		["it is the only group for people moving across", titles.filter(func(title: String) -> bool: return title.begins_with("Coming from")).size(), 1],
	])


## Pictures ship in the help folder, unimported, and decode for the page.
static func _test_pictures() -> bool:
	var path: String = EventSheetDocLibrary.shipped_picture("images/async-chip.png", "GUIDE-RECIPES")
	var texture: Texture2D = EventSheetDocPageView.shipped_picture_texture(path)
	return SUPPORT.pins(NAME, [
		["a guide's picture resolves into the help folder", path, "res://addons/eventsheet/help/images/async-chip.png"],
		["an addon guide's ../images link resolves to the same folder",
			EventSheetDocLibrary.shipped_picture("../images/async-chip.png", "Addons/Quest"), path],
		["the folder is never imported", FileAccess.file_exists("res://addons/eventsheet/help/images/.gdignore"), true],
		["the picture decodes", texture != null and texture.get_width() > 0, true],
		["a web picture is not a shipped one", EventSheetDocLibrary.shipped_picture("https://example.com/a.png", "README"), ""],
	])


## A behaviour page offers Add to project when the pack waits in the library and not in the project.
static func _test_library_page() -> bool:
	var library: String = FIXTURE_ROOT.path_join("library")
	var project: String = FIXTURE_ROOT.path_join("project")
	DirAccess.make_dir_recursive_absolute(library.path_join("platformer"))
	DirAccess.make_dir_recursive_absolute(project)
	FileAccess.open(library.path_join(".gdignore"), FileAccess.WRITE).close()
	var waiting: String = EventSheetDocBrowser.library_pack_for_page("Addons/Platformer", library, project)
	var other_page: String = EventSheetDocBrowser.library_pack_for_page("GUIDE-RECIPES", library, project)
	DirAccess.make_dir_recursive_absolute(project.path_join("platformer"))
	var held: String = EventSheetDocBrowser.library_pack_for_page("Addons/Platformer", library, project)
	DirAccess.remove_absolute(project.path_join("platformer"))
	DirAccess.remove_absolute(project)
	DirAccess.remove_absolute(library.path_join("platformer"))
	DirAccess.remove_absolute(library.path_join(".gdignore"))
	DirAccess.remove_absolute(library)
	DirAccess.remove_absolute(FIXTURE_ROOT)
	return SUPPORT.pins(NAME, [
		["a library-only pack's page offers it", waiting, "platformer"],
		["a page that is not a behaviour's offers nothing", other_page, ""],
		["a pack the project holds is not offered again", held, ""],
	])


## Events, Code and Both above every open sheet.
static func _test_view_switch() -> bool:
	var words: Dictionary = EventSheetCodePanelGlue.view_switch_words()
	return SUPPORT.pins(NAME, [
		["offered for any open sheet", EventSheetCodePanelGlue.offers_view_switch(EventSheetResource.new()), true],
		["not without a sheet", EventSheetCodePanelGlue.offers_view_switch(null), false],
		["the three words", [str(words[EventSheetPopupUI.ViewSwitch.SHEET][0]), str(words[EventSheetPopupUI.ViewSwitch.CODE][0]),
			str(words[EventSheetPopupUI.ViewSwitch.BOTH][0])], ["Events", "Code", "Both"]],
	])


## View > Manual beside the sheet. The dock itself exists only in a running editor, so headless the
## menu's answer is "not showing" and the toggle reports that nothing opened.
static func _test_manual_beside() -> bool:
	return SUPPORT.pins(NAME, [
		["headless, the Manual is not beside the sheet", EventSheetDocDock.is_shown_beside(), false],
		["headless, the toggle opens nothing", EventSheetDocDock.toggle_beside("reference:whatsnew"), false],
		["the View item's id is clear of the menu's other runs", EventSheetMenuBar.MANUAL_BESIDE_VIEW_ID, 9850],
	])


static func _key(code: Key, alt: bool) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.alt_pressed = alt
	key.pressed = true
	return key
