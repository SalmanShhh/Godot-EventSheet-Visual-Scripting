@tool
class_name EventSheetStartPage
extends RefCounted

# THE START PAGE. Everything a session starts with, on one page instead of three:
#
#   New from template   the shipped starters and the playable showcases, by genre, each with a
#                       one-line pitch and its picture
#   Recent              the sheets and scenes this project was last in
#   Learn               the tutorials, and What's new
#
# It opens when the EventSheet tab is shown with no sheet open, and from Sheet ▸ Start page. A
# checkbox turns the startup half off; the menu entry always works.
#
# Nothing here is a new way to do anything: every card calls the starter builder, the open path, or
# the Manual, all of which already exist.

const _META_KEY: String = "eventsheets_start_page_on_startup"

## The starters the page offers, as [starter id, genre, one-line pitch]. The LABEL is not repeated
## here - it comes from the starter table itself, so a renamed starter renames on this page too.
const TEMPLATE_PITCHES: Array = [
	[1, "Platformer", "Run, jump and coyote time, already wired - a character that feels right on the first run."],
	[2, "Top-down", "Eight-way movement and a camera that follows - the shape every top-down game starts from."],
	[8, "Behavior", "One behavior you attach to any node: signals in, actions out, nothing else to set up."],
	[11, "Systems", "One sheet that runs over a whole group of entities each tick, instead of a script per entity."],
	[9, "Data", "A data asset your designers fill in like a table, saved as .tres files."],
	[10, "Editor tools", "A sheet whose events run INSIDE the editor - batch renames, scene checks, one-click chores."],
	[0, "Empty", "An empty sheet. Start with a blank event and go."],
]

## The playable showcases, by genre. Discovered on disk (the folder is the id), so a showcase added
## by the example builder appears here without a list to maintain; the pitch is looked up and falls
## back to the folder's own name.
const SHOWCASE_PITCHES: Dictionary = {
	"platformer_shooter": ["Platformer", "A platformer with a weapon, enemies and pickups, playable right now."],
	"starfall": ["Arcade", "Falling objects, a score and a fail state - the whole loop in one small scene."],
	"menu_starter": ["Menus", "A title screen, options and a pause menu that already talk to each other."],
	"quest_fsm": ["Adventure", "A quest that remembers where you are, as a state machine you can read."],
	"family_arena": ["Arcade", "One rule that drives every enemy at once, through a family."],
	"path_chase": ["Top-down", "A chaser that finds its way around walls."],
	"fps_arena": ["First person", "A first-person controller with a weapon and targets."],
	"boomer_level": ["First person", "A keycard, a locked door, grunts that fight each other, and an exit tally."],
	"swarm": ["Arcade", "Hundreds of things moving at once, and still readable."],
	"draw_lab": ["Toy", "Draw shapes from events - a sandbox for the Drawing pack."],
	"input_rebind": ["Systems", "A rebinding screen that saves what the player chose."],
	"skate_park": ["Sports", "A board that keeps its speed, a rail to grind and a chain to bank."],
	"skate_park_3d": ["Sports", "The same run in three dimensions, with a bank you launch off."],
	"traversal_course": ["Platformer", "Ledges, a wall shaft, a ladder, a vault and a pool - one station per traversal move."],
	"traversal_course_3d": ["First person", "The same five traversal moves in metres, with no controller pack anywhere."],
}

const SHOWCASE_DIR: String = "res://demo/showcase"

var _dock: Control = null
var _window: Window = null
var _startup_check: CheckBox = null
var _columns_row: HBoxContainer = null


func init(dock: Control) -> void:
	_dock = dock


## Whether the page should open by itself when the workspace has no sheet. The menu entry ignores
## this - a reader who turned the startup half off can still ask for the page.
static func opens_on_startup() -> bool:
	var settings: Object = _editor_settings()
	if settings == null:
		return true
	return bool(settings.call("get_project_metadata", "eventsheets", _META_KEY, true))


static func _set_opens_on_startup(on: bool) -> void:
	var settings: Object = _editor_settings()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", _META_KEY, on)


## The three columns, as [{id, title, entries}] where each entry is
## {kind, label, note, target}. Pure, so a test pins the page's contents without building it.
##   kind "template"  target = the starter id, as text
##   kind "showcase"  target = the scene path
##   kind "recent"    target = the file path
##   kind "learn"     target = the Manual doc id
##   kind "this_editor"  target = "" (only in the plugin's own repo)
static func columns(starters: Array, showcases: PackedStringArray, recents: Array,
		is_editor_project: bool = false) -> Array:
	var templates: Array = []
	var label_by_id: Dictionary = {}
	for starter: Variant in starters:
		label_by_id[int((starter as Dictionary).get("id", -1))] = str((starter as Dictionary).get("label", ""))
	for entry: Variant in TEMPLATE_PITCHES:
		var record: Array = entry
		var starter_id: int = int(record[0])
		if not label_by_id.has(starter_id):
			continue
		templates.append({"kind": "template", "label": str(label_by_id[starter_id]),
			"note": "%s · %s" % [str(record[1]), str(record[2])], "target": str(starter_id)})
	for showcase: String in showcases:
		var pitch: Variant = SHOWCASE_PITCHES.get(showcase)
		var genre: String = str((pitch as Array)[0]) if pitch is Array else "Showcase"
		var line: String = str((pitch as Array)[1]) if pitch is Array \
			else "A playable example you can open and take apart."
		templates.append({"kind": "showcase", "label": showcase.capitalize(),
			"note": "%s · %s" % [genre, line], "target": "%s/%s" % [SHOWCASE_DIR, showcase]})
	var recent_entries: Array = []
	for path: Variant in recents:
		# The health card's short form is the Recent list's second column: how many events the
		# sheet has and how its tests last went, read from the file rather than by loading it.
		recent_entries.append({"kind": "recent", "label": str(path).get_file(),
			"note": EventSheetHealthCard.brief_for_path(str(path), str(path).get_base_dir()),
			"target": str(path)})
	var learn: Array = []
	for tutorial: Dictionary in EventSheetDocTutorials.tutorials():
		learn.append({
			"kind": "learn", "label": str(tutorial.get("title", "")),
			"note": "%d min" % int(tutorial.get("minutes", 0)),
			"target": EventSheetDocTutorials.doc_id(str(tutorial.get("id", "")))
		})
	learn.append({"kind": "learn", "label": "What's new", "note": "since you last looked",
		"target": "reference:whats-new"})
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
			"label": "This is the editor's own project - open its source as sheets",
			"note": "Every file the editor is built from, grouped by what it does, read the way your own scripts are.",
			"target": ""
		}]})
	return built


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


## Sheet ▸ Start page, and the no-sheet startup.
func open() -> void:
	_build()
	_fill()
	_window.popup_centered()


## The startup half: only when the reader left it on, and only with nothing open.
func open_if_idle() -> void:
	if not opens_on_startup() or _dock._current_sheet != null:
		return
	open()


func _build() -> void:
	if _window != null:
		return
	_window = Window.new()
	_window.title = "Start"
	_window.size = Vector2i(EventSheetPalette.scaled(900), EventSheetPalette.scaled(520))
	_window.close_requested.connect(func() -> void: _window.hide())
	var outer: VBoxContainer = EventSheetPopupUI.form_box()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns_row = HBoxContainer.new()
	_columns_row.add_theme_constant_override("separation", 12)
	_columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_columns_row)
	_startup_check = CheckBox.new()
	_startup_check.text = "Show this page when nothing is open"
	_startup_check.tooltip_text = "Off means the Start page only opens from Sheet ▸ Start page."
	_startup_check.button_pressed = opens_on_startup()
	_startup_check.toggled.connect(func(on: bool) -> void: _set_opens_on_startup(on))
	outer.add_child(_startup_check)
	# The margin wrapper is what the window holds, so IT is the thing that has to fill the window.
	# Anchoring the box INSIDE a wrapper that does not fill left all three columns collapsed to their
	# titles in the top-left corner - the page opened, and it opened empty.
	var margined: MarginContainer = EventSheetPopupUI.margined(outer)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(margined)
	_dock.add_child(_window)


func _fill() -> void:
	# Removed as well as freed: queue_free lands at the end of the frame, so a plain queue_free would
	# leave the second open showing six columns for one frame before settling back to three.
	for child: Node in _columns_row.get_children():
		_columns_row.remove_child(child)
		child.queue_free()
	var recents: Array = _dock.get_open_sheets_state().get("recent", [])
	for column: Variant in columns(EventSheetStarterTemplates.create_new_starters(),
			showcase_folders(), recents, EventSheetThisEditor.is_editor_project()):
		var section: Dictionary = column
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for entry: Variant in section.get("entries", []):
			list.add_child(_entry_card(entry as Dictionary))
		if (section.get("entries", []) as Array).is_empty():
			var empty := Label.new()
			empty.text = "Nothing here yet."
			empty.modulate = Color(1.0, 1.0, 1.0, 0.6)
			list.add_child(empty)
		scroll.add_child(list)
		box.add_child(scroll)
		var card: PanelContainer = EventSheetPopupUI.titled_card(str(section.get("title", "")), box)
		# Without these the three cards shrink to their titles: an HBoxContainer hands out no space
		# a child did not ask for.
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_columns_row.add_child(card)


func _entry_card(entry: Dictionary) -> Control:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = str(entry.get("label", ""))
	button.tooltip_text = str(entry.get("note", ""))
	button.pressed.connect(activate.bind(entry))
	return button


## What a card does. Every branch is a path the editor already has.
func activate(entry: Dictionary) -> void:
	var target: String = str(entry.get("target", ""))
	match str(entry.get("kind", "")):
		"template":
			EventSheetProjectBarGlue.mark_started_from_template()
			_dock._starter._new_sheet_from_template(int(target))
		"showcase":
			_open_showcase(target)
		"recent":
			_dock.reopen_sheet_path(target)
		"learn":
			_dock.open_documentation(target)
		"this_editor":
			_open_this_editor_folder()
	if _window != null:
		_window.hide()


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


## A showcase folder opens its scene in Godot's own editor - the point of a showcase is that it runs.
func _open_showcase(folder_path: String) -> void:
	var scene_path: String = ""
	if DirAccess.dir_exists_absolute(folder_path):
		var names: PackedStringArray = DirAccess.get_files_at(folder_path)
		names.sort()
		for file_name: String in names:
			if file_name.get_extension() == "tscn":
				scene_path = "%s/%s" % [folder_path, file_name]
	if scene_path.is_empty():
		_dock._set_status("That showcase has no scene to open.", true)
		return
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("open_scene_from_path"):
			editor_interface.call("open_scene_from_path", scene_path)
	_dock._set_status("Opened %s - press Play to try it, then open its scripts as sheets." % scene_path.get_file())


static func _editor_settings() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_settings"):
		return null
	return editor_interface.call("get_editor_settings")
