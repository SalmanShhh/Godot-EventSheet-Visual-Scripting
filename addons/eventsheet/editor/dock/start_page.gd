@tool
class_name EventSheetStartPage
extends RefCounted

# THE START PAGE. Everything a session starts with, on one page instead of three:
#
#   New from template   "Open an existing script" first, then the shipped starters by shelf (2D,
#                       3D, menus, behaviours, project-wide, game shapes, data, editor tools) and
#                       the playable showcases; chips above narrow it to one shelf
#   Recent              the sheets and scenes this project was last in
#   Learn               the tutorials, and What's new
#
# Each row shows its kind beside its name. A click selects and the help strip at the foot says what
# the row is and what opening it does; Open, Enter or a double-click opens it.
#
# It opens when the EventSheet tab is shown with no sheet open, and from Sheet ▸ Start page. A
# checkbox turns the startup half off; the menu entry always works.
#
# Nothing here is a new way to do anything: every row calls the starter builder, the open path, or
# the Manual, all of which already exist.

const _META_KEY: String = "eventsheets_start_page_on_startup"

## The shelf each showcase folder sits on. A showcase says what it DOES in the about comment its
## sheet opens with, and `pitch_from_about` turns that into the line a card shows - but nothing in
## the file says which shelf a reader looks on for it, so the genre stays written down here. It is
## the one fact this page can fall behind a new showcase on, which is why the suite pins it: a
## folder under demo/showcase with no entry fails.
const SHOWCASE_KINDS: Dictionary = {
	"boomer_level": "First person",
	"carousel": "Feel",
	"combo_fighter": "Fighting",
	"draw_lab": "Toy",
	"enemy_stats": "Data",
	"family_arena": "Arcade",
	"fps_arena": "First person",
	"hierarchy_playground": "Toy",
	"htn_agent": "AI",
	"input_rebind": "Systems",
	"inspector_playground": "Toy",
	"menu_starter": "Menus",
	"mirror_and_flip": "Toy",
	"path_chase": "Platformer",
	"pin_modes": "Toy",
	"platformer_pathfinding": "Platformer",
	"platformer_shooter": "Platformer",
	"quest_fsm": "Adventure",
	"raycast_lab": "Toy",
	"raycast_lab_3d": "Toy",
	"skate_park": "Sports",
	"skate_park_3d": "Sports",
	"skill_tree": "Systems",
	"starfall": "Arcade",
	"swarm": "Arcade",
	"top_down_shooter": "Arcade",
	"traversal_course": "Platformer",
	"traversal_course_3d": "First person",
	"uhtn_planning": "AI",
	"utility_ai": "AI",
}

## The pitches still WRITTEN here rather than read off the showcase. Two of them carry no about
## comment at all; the rest were written for this page back when it listed a handful of showcases by
## hand, and they still read better on a card than the showcase's own opening clause does. Every
## other folder gets its line from the showcase itself, and an entry here retires the day its
## showcase says it as well - nothing else has to change when it does.
const SHOWCASE_PITCHES: Dictionary = {
	"platformer_shooter": "A platformer with a weapon, enemies and pickups, playable right now.",
	"starfall": "Falling objects, a score and a fail state - the whole loop in one small scene.",
	"menu_starter": "A title screen, options and a pause menu that already talk to each other.",
	"quest_fsm": "A quest that remembers where you are, as a state machine you can read.",
	"family_arena": "One rule that drives every enemy at once, through a family.",
	"fps_arena": "A first-person controller with a weapon and targets.",
	"boomer_level": "A keycard, a locked door, grunts that fight each other, and an exit tally.",
	"swarm": "Hundreds of things moving at once, and still readable.",
	"draw_lab": "Draw shapes from events - a sandbox for the Drawing pack.",
	"input_rebind": "A rebinding screen that saves what the player chose.",
	"skate_park": "A board that keeps its speed, a rail to grind and a chain to bank.",
	"skate_park_3d": "The same run in three dimensions, with a bank you launch off.",
	"traversal_course": "Ledges, a wall shaft, a ladder, a vault and a pool - one station per traversal move.",
	"traversal_course_3d": "The same five traversal moves in metres, with no controller pack anywhere.",
}

## What a card falls back to when a showcase neither names a pitch here nor describes itself.
const SHOWCASE_UNDESCRIBED: String = "A playable example you can open and take apart."

## What a card falls back to when a folder has no shelf yet. It is a visible word rather than an
## empty one, so a missing entry reads as missing on the page as well as in the suite.
const SHOWCASE_UNSHELVED: String = "Showcase"

## How a showcase sheet opens its description: a comment row whose first mark is the bold title.
const ABOUT_PREFIX: String = "# [b]"

## How far into an about comment the "Title - " lead may reach. Past that the dash is punctuation in
## a sentence rather than the separator after a name, and cutting there would eat the pitch.
const ABOUT_LEAD_LIMIT: int = 48

const SHOWCASE_DIR: String = "res://demo/showcase"

var _dock: Control = null
var _window: Window = null
var _columns_row: HBoxContainer = null
var _lists: Array[Tree] = []
var _strip: EventSheetPopupUI.HelpStrip = null
var _opens_value: Label = null
var _open_button: Button = null
## The row the reader picked last, from whichever column; {} while nothing is picked.
var _chosen: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


## Whether the page should open by itself when the workspace has no sheet. The menu entry ignores
## this - a reader who turned the startup half off can still ask for the page.
static func opens_on_startup() -> bool:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return true
	return bool(settings.call("get_project_metadata", "eventsheets", _META_KEY, true))


static func _set_opens_on_startup(on: bool) -> void:
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", _META_KEY, on)


## The shelf a row sits on when it is the reader's own project rather than a starter. It leads the
## column: a project that already has scripts is the common case, so opening one comes first.
const SHELF_YOUR_PROJECT: String = "Your project"
const SHELF_EDITOR_TOOLS: String = "Editor tools"
const SHELF_SHOWCASES: String = "Showcases"
## The first row of the Behaviours and the Project-wide shelves, by shelf: the New behaviour and New
## global forms, for when no sheet is open yet to reach them from the Sheet menu.
const MAKERS: Dictionary = {
	"Behaviours": {"label": "New behaviour…", "tag": "Your own", "target": "behaviour",
		"pitch": "Make a behaviour of your own: its name, what it works on, where it is listed, then open it as a sheet."},
	"Project-wide (autoloads)": {"label": "New global…", "tag": "Your own", "target": "global",
		"pitch": "Make a global of your own: its name, script or scene, then turn it on in Project Settings > Globals."},
}


## The three columns, as [{id, title, entries}] where each entry is
## {kind, label, tag, pitch, shelf, target}: `tag` is the kind word drawn beside the name, `pitch`
## the line the help strip says, `shelf` the heading it sits under (templates only). Pure, so a test
## pins the page's contents without building it.
##   kind "open_script"  target = "" (the Open file picker)
##   kind "template"     target = the starter id, as text
##   kind "editor_tool"  target = "" (the list of editor tool shapes)
##   kind "showcase"     target = the folder path (its line comes from `abouts`, {folder: about text})
##   kind "recent"       target = the file path
##   kind "learn"        target = the Manual doc id
##   kind "this_editor"  target = "" (only in the plugin's own repo)
static func columns(showcases: PackedStringArray, recents: Array,
		is_editor_project: bool = false, abouts: Dictionary = {}) -> Array:
	var templates: Array = [{"kind": "open_script", "label": "Open an existing script…", "tag": "Your scripts",
		"pitch": "Any script in this project reads as a sheet, and saving it untouched leaves the file exactly as it was.",
		"shelf": SHELF_YOUR_PROJECT, "target": ""}]
	for starter: Dictionary in _starters_by_shelf():
		# The Behaviours and Project-wide shelves open on the form that makes one of your own.
		var maker: Dictionary = MAKERS.get(str(starter["shelf"]), {})
		if not maker.is_empty() and shelves(templates).find(str(starter["shelf"])) < 0:
			templates.append(maker.merged({"kind": "maker", "shelf": str(starter["shelf"])}))
		templates.append({"kind": "template", "label": str(starter["label"]).get_slice(" (", 0),
			"tag": str(starter["kind"]), "pitch": str(starter["pitch"]), "shelf": str(starter["shelf"]),
			"target": str(starter["id"])})
	templates.append({"kind": "editor_tool", "label": "Editor Tool…", "tag": "@tool",
		"pitch": "A sheet whose events run INSIDE the editor - batch renames, scene checks, one-click chores.",
		"shelf": SHELF_EDITOR_TOOLS, "target": ""})
	for showcase: String in showcases:
		var line: String = str(SHOWCASE_PITCHES.get(showcase, ""))
		if line.is_empty():
			line = pitch_from_about(str(abouts.get(showcase, "")))
		templates.append({"kind": "showcase", "label": showcase.capitalize(),
			"tag": str(SHOWCASE_KINDS.get(showcase, SHOWCASE_UNSHELVED)),
			"pitch": line if not line.is_empty() else SHOWCASE_UNDESCRIBED, "shelf": SHELF_SHOWCASES,
			"target": "%s/%s" % [SHOWCASE_DIR, showcase]})
	var recent_entries: Array = []
	for path: Variant in recents:
		# The health card's short form is the Recent list's second column: how many events the
		# sheet has and how its tests last went, read from the file rather than by loading it.
		recent_entries.append({"kind": "recent", "label": str(path).get_file(),
			"tag": EventSheetHealthCard.brief_for_path(str(path), str(path).get_base_dir()),
			"pitch": str(path), "target": str(path)})
	var learn: Array = []
	for tutorial: Dictionary in EventSheetDocTutorials.tutorials():
		learn.append({"kind": "learn", "label": str(tutorial.get("title", "")),
			"tag": "%d min" % int(tutorial.get("minutes", 0)), "pitch": str(tutorial.get("lead", "")),
			"target": EventSheetDocTutorials.doc_id(str(tutorial.get("id", "")))})
	learn.append({"kind": "learn", "label": "What's new", "tag": "since you last looked",
		"pitch": "What changed in the editor since you last looked.", "target": "reference:whats-new"})
	var built: Array = [
		{"id": "templates", "title": "New from template", "entries": templates},
		{"id": "recent", "title": "Recent", "entries": recent_entries},
		{"id": "learn", "title": "Learn", "entries": learn},
	]
	# The contributor's door, and only in the editor's own repo. A game project's Start page is
	# exactly what it always was.
	if is_editor_project:
		built.append({"id": "this_editor", "title": "This editor", "entries": [{
			"kind": "this_editor",
			"label": "This is the editor's own project - open its source as sheets", "tag": "",
			"pitch": "Every file the editor is built from, grouped by what it does, read the way your own scripts are.",
			"target": ""
		}]})
	return built


## The menu's starters with each shelf gathered into one run, the shelves in the order they first
## appear and the starters in menu order within a shelf. The menu interleaves them (Keycard Door is
## a 3D starter listed after two menus), and the list draws a heading wherever the shelf changes, so
## without this the page reads a second "3D" heading under "UI and menus".
static func _starters_by_shelf() -> Array[Dictionary]:
	var order: PackedStringArray = PackedStringArray()
	var by_shelf: Dictionary = {}
	for starter: Dictionary in EventSheetStarterTemplates.MENU_STARTERS:
		var shelf: String = str(starter["shelf"])
		if not by_shelf.has(shelf):
			order.append(shelf)
			by_shelf[shelf] = []
		(by_shelf[shelf] as Array).append(starter)
	var grouped: Array[Dictionary] = []
	for shelf: String in order:
		for starter: Variant in by_shelf[shelf]:
			grouped.append(starter as Dictionary)
	return grouped


## The shelves of the template column in the order they first appear - the filter chips' order.
static func shelves(entries: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		var shelf: String = str((entry as Dictionary).get("shelf", ""))
		if not shelf.is_empty() and not found.has(shelf):
			found.append(shelf)
	return found


## What opening a row does, said before it is opened - the strip's OPENS line.
static func opens_line(entry: Dictionary) -> String:
	var target: String = str(entry.get("target", ""))
	match str(entry.get("kind", "")):
		"open_script":
			return EventSheetL10n.translate("The file picker, at this project's scripts.")
		"template":
			return EventSheetL10n.translate("%s as a new unsaved sheet - Save As… keeps it.") % str(entry.get("label", ""))
		"maker":
			return EventSheetL10n.translate("The New global form.") if target == "global" \
				else EventSheetL10n.translate("The New behaviour form.")
		"editor_tool":
			return EventSheetL10n.translate("The list of editor tool kinds, to pick which one to start from.")
		"showcase":
			return EventSheetL10n.translate("%s in Godot's scene editor - press Play to try it.") % showcase_scene(target).get_file()
		"recent":
			return EventSheetL10n.translate("%s in the sheet editor.") % target
		"learn":
			return EventSheetL10n.translate("This lesson in the Manual, beside the sheet.")
	return EventSheetL10n.translate("The Project bar, at the editor's own source.")


## The showcase folders on disk, sorted. Empty when the project has no demo folder, which is the
## normal case for a user's own project - the column simply carries the starters then.
static func showcase_folders() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(SHOWCASE_DIR):
		return found
	for folder: String in DirAccess.get_directories_at(SHOWCASE_DIR):
		found.append(folder)
	found.sort()
	return found


## The about comment a showcase opens with, or "" when it carries none. A showcase sheet's first
## comment row IS its description, so the page reads that instead of keeping a second copy of it
## that can disagree. The folder-named script is asked first: a folder with several sheets (an
## enemy, a door, a pickup) has exactly one that is the showcase, and it is named after the folder.
static func showcase_about(folder: String) -> String:
	var folder_path: String = "%s/%s" % [SHOWCASE_DIR, folder]
	var scripts: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder_path):
		if file_name.get_extension() == "gd":
			scripts.append(file_name)
	scripts.sort()
	var ordered: PackedStringArray = PackedStringArray()
	if scripts.has("%s.gd" % folder):
		ordered.append("%s.gd" % folder)
	for file_name: String in scripts:
		if not ordered.has(file_name):
			ordered.append(file_name)
	for file_name: String in ordered:
		for line: String in FileAccess.get_file_as_string("%s/%s" % [folder_path, file_name]).split("\n"):
			if line.begins_with(ABOUT_PREFIX):
				return line.substr(2).strip_edges()
	return ""


## Every showcase folder and the about comment it opens with, {folder: about text}, ready for
## `columns`. Reading the folders is a disk walk and `columns` is pure, so the walk happens here.
static func showcase_abouts(folders: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for folder: String in folders:
		found[folder] = showcase_about(folder)
	return found


## The ONE line a card shows, cut out of a showcase's about comment. The about text is a paragraph
## written for somebody already reading the sheet, so the card takes the first thing it says and
## stops: at the end of the first sentence, at the colon that introduces a list, or at the "and"
## that opens a second clause, whichever comes first. The bold title in front is dropped with the
## rest of the marks, because the card already carries the name.
static func pitch_from_about(about: String) -> String:
	var text: String = _without_marks(about)
	var lead: int = text.find(" - ")
	if lead > 0 and lead <= ABOUT_LEAD_LIMIT:
		text = text.substr(lead + 3)
	var cut: int = text.length()
	for ending: String in [". ", ": ", ", and "]:
		var at: int = text.find(ending)
		if at < 0:
			continue
		# The sentence keeps its full stop; the other two are joins, and the pitch ends before them.
		cut = mini(cut, at + 1 if ending == ". " else at)
	text = text.substr(0, cut).strip_edges()
	if text.is_empty():
		return ""
	if not text.ends_with("."):
		text = "%s." % text
	# The clause was the middle of a sentence and the card is a line of its own, so it gets a
	# sentence's capital to sit beside the pitches written here, which have always had one.
	return text.substr(0, 1).to_upper() + text.substr(1)


## The same text without its display marks. A card is a Button - it shows the characters it is
## given, so a `[b]` left in reads as three of them.
static func _without_marks(text: String) -> String:
	var marks: RegEx = RegEx.create_from_string("\\[/?[a-zA-Z][^\\]]*\\]")
	return marks.sub(text, "", true) if marks != null else text


## The showcase folders this page has no shelf for. The genre is the one fact the page still writes
## down itself, so it is the one a new showcase can leave behind; the suite pins this empty.
static func showcases_without_a_shelf() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for folder: String in showcase_folders():
		if not SHOWCASE_KINDS.has(folder):
			missing.append(folder)
	return missing


## Shelves and pitches naming a folder that is not there - a showcase renamed or retired with its
## entry left behind. Sorted, so the suite names them in one order on every filesystem.
static func shelves_without_a_showcase() -> PackedStringArray:
	var folders: PackedStringArray = showcase_folders()
	var stale: PackedStringArray = PackedStringArray()
	for folder: Variant in SHOWCASE_KINDS.keys():
		if not folders.has(str(folder)):
			stale.append(str(folder))
	for folder: Variant in SHOWCASE_PITCHES.keys():
		if not folders.has(str(folder)) and not stale.has(str(folder)):
			stale.append(str(folder))
	stale.sort()
	return stale


## Sheet ▸ Start page, and the no-sheet startup.
func open() -> void:
	_build()
	_fill()
	_window.popup_centered()


func _build() -> void:
	if _window != null:
		return
	_window = Window.new()
	_window.title = EventSheetL10n.translate("Start - open a sheet or make one")
	_window.size = Vector2i(EventSheetPalette.scaled(1120), EventSheetPalette.scaled(640))
	_window.close_requested.connect(_window.hide)
	var outer: VBoxContainer = EventSheetPopupUI.form_box()
	_columns_row = HBoxContainer.new()
	_columns_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(12.0)))
	_columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_columns_row)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(640.0))
	_opens_value = _strip.add_line(EventSheetL10n.translate("OPENS"))
	outer.add_child(_strip)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var startup_check: CheckBox = CheckBox.new()
	startup_check.text = "Show this page when nothing is open"
	startup_check.tooltip_text = "Off means the Start page only opens from Sheet ▸ Start page."
	startup_check.button_pressed = opens_on_startup()
	startup_check.toggled.connect(_set_opens_on_startup)
	startup_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(startup_check)
	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_window.hide)
	foot.add_child(close_button)
	_open_button = Button.new()
	_open_button.text = "Open"
	_open_button.pressed.connect(func() -> void: activate(_chosen))
	foot.add_child(_open_button)
	outer.add_child(foot)
	# The painted body is what the window holds, so IT fills the window (window_body anchors it):
	# anchoring the box INSIDE a wrapper that does not fill left all three columns collapsed to their
	# titles in the top-left corner - the page opened, and it opened empty.
	_window.add_child(EventSheetPopupUI.window_body(outer))
	_dock.add_child(_window)


func _fill() -> void:
	# Removed as well as freed: queue_free lands at the end of the frame, so a plain queue_free would
	# leave the second open showing six columns for one frame before settling back to three.
	for child: Node in _columns_row.get_children():
		_columns_row.remove_child(child)
		child.queue_free()
	_lists.clear()
	_choose({})
	var folders: PackedStringArray = showcase_folders()
	for column: Variant in columns(folders, _dock.get_open_sheets_state().get("recent", []),
			EventSheetThisEditor.is_editor_project(), showcase_abouts(folders)):
		var section: Dictionary = column
		var entries: Array = section.get("entries", [])
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var list: Tree = Tree.new()
		list.columns = 2
		list.hide_root = true
		list.select_mode = Tree.SELECT_ROW
		# The kind is the quieter, narrower column; the name gets three parts of four.
		list.set_column_expand_ratio(0, 3)
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.item_selected.connect(func() -> void:
			for other: Tree in _lists:
				if other != list:
					other.deselect_all()
			_choose(list.get_selected().get_metadata(0) as Dictionary))
		list.item_activated.connect(func() -> void: activate(_chosen))
		_lists.append(list)
		if str(section.get("id", "")) == "templates":
			box.add_child(_shelf_chips(list, entries))
		_fill_list(list, entries)
		box.add_child(list)
		var card: PanelContainer = EventSheetPopupUI.titled_card(str(section.get("title", "")), box)
		# Without these the cards shrink to their titles: an HBoxContainer hands out no space a
		# child did not ask for. The template column is the one with the most to show.
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 2.0 if str(section.get("id", "")) == "templates" else 1.0
		_columns_row.add_child(card)


## One row per entry - its name, and its kind in the quieter second column - under the heading of
## each shelf it reaches. `shelf` keeps one shelf only; "" keeps them all.
func _fill_list(list: Tree, entries: Array, shelf: String = "") -> void:
	list.clear()
	var root: TreeItem = list.create_item()
	var heading: String = ""
	for entry: Variant in entries:
		var row: Dictionary = entry
		var row_shelf: String = str(row.get("shelf", ""))
		# The reader's own project stays on top whichever shelf is chosen.
		if not shelf.is_empty() and row_shelf != shelf and row_shelf != SHELF_YOUR_PROJECT:
			continue
		if row_shelf != heading:
			heading = row_shelf
			var head: TreeItem = list.create_item(root)
			head.set_text(0, heading.to_upper())
			head.set_custom_color(0, EventSheetPopupUI.accent_color())
			head.set_custom_font(0, EventSheetPopupUI.small_caps_font(list.get_theme_font("font")))
			head.set_custom_font_size(0, EventSheetPalette.scaled(EventSheetPopupUI.SMALL_CAPS_FONT_SIZE))
			head.set_selectable(0, false)
			head.set_selectable(1, false)
		var item: TreeItem = list.create_item(root)
		item.set_text(0, str(row.get("label", "")))
		item.set_text(1, str(row.get("tag", "")))
		item.set_tooltip_text(0, str(row.get("label", "")))
		item.set_custom_color(1, EventSheetPopupUI.muted_text_color())
		item.set_metadata(0, row)
	if root.get_child_count() == 0:
		var empty: TreeItem = list.create_item(root)
		empty.set_text(0, "Nothing here yet.")
		empty.set_custom_color(0, EventSheetPopupUI.muted_text_color())
		empty.set_selectable(0, false)
		empty.set_selectable(1, false)


## The chips over the template column: All, then one per shelf. A chip narrows the list to its shelf.
func _shelf_chips(list: Tree, entries: Array) -> HFlowContainer:
	var chips: HFlowContainer = HFlowContainer.new()
	var group: ButtonGroup = ButtonGroup.new()
	var shelf_names: PackedStringArray = PackedStringArray([""])
	shelf_names.append_array(shelves(entries))
	shelf_names.erase(SHELF_YOUR_PROJECT)
	for shelf: String in shelf_names:
		var chip: Button = Button.new()
		# The chip is the heading's first words: "Project-wide", not "Project-wide (autoloads)".
		chip.text = shelf.get_slice(" (", 0) if not shelf.is_empty() else EventSheetL10n.translate("All")
		chip.toggle_mode = true
		chip.button_group = group
		chip.flat = true
		chip.set_pressed_no_signal(shelf.is_empty())
		chip.pressed.connect(func() -> void: _fill_list(list, entries, shelf))
		chips.add_child(chip)
	return chips


## What the help strip says about the chosen row, and whether Open has anything to open.
func _choose(entry: Dictionary) -> void:
	_chosen = entry
	_open_button.disabled = entry.is_empty()
	if entry.is_empty():
		_strip.describe(EventSheetL10n.translate("This entry"),
			EventSheetL10n.translate("Pick a row to see what it is; Open or a double-click opens it."))
		_strip.set_line(_opens_value, "")
		return
	var tag: String = EventSheetL10n.translate(str(entry.get("tag", "")))
	var pitch: String = EventSheetL10n.translate(str(entry.get("pitch", "")))
	_strip.describe(EventSheetL10n.translate("This entry"), pitch if tag.is_empty() else "%s · %s" % [tag, pitch])
	_strip.set_line(_opens_value, opens_line(entry))


## What a row does. Every branch is a path the editor already has.
func activate(entry: Dictionary) -> void:
	var target: String = str(entry.get("target", ""))
	match str(entry.get("kind", "")):
		"open_script":
			_dock._on_open_requested()
		"template":
			_dock._starter._new_sheet_from_template(int(target))
		"maker":
			_dock._new_addon_panel.open(target == "global")
		"editor_tool":
			_pick_editor_tool()
			return
		"showcase":
			_open_showcase(target)
		"recent":
			_dock.reopen_sheet_path(target)
		"learn":
			_dock.open_documentation(target)
		"this_editor":
			_open_this_editor_folder()
		_:
			return
	if _window != null:
		_window.hide()


## The editor tool kinds, as the New-Sheet menu's Editor Tool submenu lists them; picking one opens
## that starter like any other row.
func _pick_editor_tool() -> void:
	var menu: PopupMenu = PopupMenu.new()
	for shape: Dictionary in EventSheetStarterTemplates.EDITOR_TOOL_SHAPES:
		menu.add_item("%s - %s" % [str(shape["label"]), str(shape["note"])], int(shape["id"]))
	menu.id_pressed.connect(func(id: int) -> void: activate({"kind": "template", "target": str(id)}))
	menu.popup_hide.connect(menu.queue_free, CONNECT_DEFERRED)
	_window.add_child(menu)
	menu.popup(Rect2i(Vector2i(_window.get_mouse_position()) + _window.position, Vector2i.ZERO))


## The contributor's door: turn the Project bar on, open it, and open the plugin's own script
## as the first thing they read. Everything here is a gesture the reader could make by hand; the card
## just makes it one click instead of four.
func _open_this_editor_folder() -> void:
	_dock._project_bar_glue.set_shown(true)
	var bar: EventSheetProjectBar = _dock._project_bar_glue.bar()
	if bar != null:
		bar.set_expanded(true)
		bar.open_this_editor_folder()
	_dock._navigate.open_or_focus(EventSheetThisEditor.PLUGIN_SCRIPT_PATH)
	_dock._set_status("The editor's own source, in the Project bar under This editor. Every file is read-only until you say Edit anyway.")


## The scene a showcase folder runs from. A folder also holds the scenes its main scene spawns (a
## shot, an enemy), so the main one is the scene named after the folder - `<folder>.tscn`, or
## `showcase_<folder>.tscn` - and only a folder with neither falls back to its first scene by name.
## Empty when the folder has no scene at all.
static func showcase_scene(folder_path: String) -> String:
	if not DirAccess.dir_exists_absolute(folder_path):
		return ""
	var names: PackedStringArray = DirAccess.get_files_at(folder_path)
	names.sort()
	var folder: String = folder_path.trim_suffix("/").get_file()
	for wanted: String in ["%s.tscn" % folder, "showcase_%s.tscn" % folder]:
		if names.has(wanted):
			return folder_path.path_join(wanted)
	for file_name: String in names:
		if file_name.get_extension() == "tscn":
			return folder_path.path_join(file_name)
	return ""


## A showcase folder opens its scene in Godot's own editor - the point of a showcase is that it runs.
func _open_showcase(folder_path: String) -> void:
	var scene_path: String = showcase_scene(folder_path)
	if scene_path.is_empty():
		_dock._set_status("That showcase has no scene to open.", true)
		return
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("open_scene_from_path"):
			editor_interface.call("open_scene_from_path", scene_path)
	_dock._set_status("Opened %s - press Play to try it, then open its scripts as sheets." % scene_path.get_file())
