# EventSheet - ACE Picker dialog component
# Owns the picker window, search field, grouped/filtered tree, and mode-aware filtering.
# Use open() to show it and connect to ace_selected to receive the chosen ACEDefinition.
#
# Event-sheet-style presentation:
#  - Entries are grouped by Godot node type (ACEDefinition.metadata.node_type) when set,
#    otherwise by category. With no query every section starts COLLAPSED (a scannable table
#    of contents - pick the object, then browse its verbs); searching rebuilds expanded.
#  - Each row carries a small dot in its ACE type's role colour (trigger purple, condition
#    teal, action amber, expression magenta - the sheet's own lane colours), and its tooltip
#    is prefixed with the type, e.g. "[Condition]  Is on floor". Featured rows are bold with
#    a leading star.
#  - In event-creation modes the node-type sections are pre-declared (always present) and,
#    while searching, empty sections are hidden so only matching groups remain.
@tool
class_name ACEPickerDialog
extends RefCounted

## Emitted when the user double-clicks or activates a definition in the picker.
## context is the same dictionary passed to open().
signal ace_selected(definition: ACEDefinition, context: Dictionary)
## The reader asked to read more about the highlighted verb (the "Open <Pack>'s guide" link
## affordance). Emitted, never acted on here: where that reading happens is the docs surface's
## call, not the picker's.
signal guide_requested(definition: ACEDefinition)

## Emitted when the reader presses the "?" on an entry. The Manual is where that is answered; this
## dialog only says which verb was asked about.
signal help_requested(definition: ACEDefinition)

## Emitted when the reader takes the Add event dialog's first entry, "(none - runs every tick)".
## A blank event is a real event with no condition of its own, so there is no definition to hand over -
## only the context the dialog was opened with, which says where the new event goes.
signal blank_event_selected(context: Dictionary)

## Recents (familiar ACEs surface first): last-used ACE ids, newest first. Persisted PER-USER and
## PER-PROJECT in a user:// file - NOT project.godot: recents change on every ACE use and would churn
## the version-controlled file constantly (Favorites live in ProjectSettings because they change rarely).
static var _recent_ace_ids: PackedStringArray = PackedStringArray()
static var _recents_loaded: bool = false
const RECENT_ACES_CAP := 8
const RECENTS_FILE := "user://eventforge_picker_recents.cfg"

## ⭐ Favorites persist in ProjectSettings - per-project and PR-shareable, like the
## composition policy. Right-click a picker entry to pin/unpin.
const FAVORITES_SETTING := "eventsheets/picker/favorites"
## Marks an object-card entry as "hidden class, select to restore" rather than a scope target.
const UNHIDE_PREFIX := "unhide:"

## The page the 3D verbs are filed on. A category starting with this names a page and a section
## ("3D: Move & Turn"), and is filed as one even though the row is also scoped to a node type.
const SPATIAL_PAGE_PREFIX := "3D: "

## Marks an object-page entry as "one of the open script's own functions - insert a call to it"
## rather than a scope target. The rest of the string is the GDScript function name.
const FUNCTION_PREFIX := "function:"
## Where a Functions entry stashes the function it targets, so the single commit path can pre-fill
## the Call Function parameters instead of needing a second dispatch table.
const FUNCTION_META_KEY := "eventsheet_function_name"

## The three things a row built FOR one node of the open scene carries: the node it is
## aimed at (pre-filled into the params dialog, exactly as a Functions entry pre-fills its function),
## the shelf it is offered on, and the group that shelf sits in. Metadata rather than fields, because
## the copy is a picker entry and the row it makes is the ordinary node-scoped row with its target
## answered.
const SCENE_TARGET_META := "eventsheet_light_target"
const SCENE_SHELF_META := "eventsheet_light_shelf"
const SCENE_GROUP_META := "eventsheet_light_group"

## And the values a shelf entry answers BESIDES its node - a Dictionary of param id to value, merged
## into the params dialog exactly as the target is. An effect entry is built for one dial as well as
## for one node, so both are answered before the dialog opens and the reader edits the value.
const SCENE_PREFILL_META := "eventsheet_scene_prefill"

## Where the LIGHTING NODES of the open scene are offered: one folder per kind of thing,
## one sub-folder per node. The sixteen Core lighting actions and the per-class groups are untouched
## beside them - these are the shelves for "which of MY lights", which is the question a reader
## actually arrives with, and its two neighbours for the darkness and the atmosphere.
const LIGHTS_GROUP := "Lights in this scene"
const DARKNESS_GROUP := "Darkness in this scene"
const ATMOSPHERE_GROUP := "Atmosphere in this scene"

## The shelves themselves: the group each is titled with, and the class of node it offers.
## An empty `root` means "any light", which is asked of ClassDB rather than of a list, so a light
## class the engine adds - or one a project subclasses - is on the shelf without an edit here.
const SCENE_SHELVES: Array[Dictionary] = [
	{"group": LIGHTS_GROUP, "root": ""},
	{"group": DARKNESS_GROUP, "root": "CanvasModulate"},
	{"group": ATMOSPHERE_GROUP, "root": "WorldEnvironment"},
]

## Where the EFFECTS of the open scene are offered: one folder per node wearing a shader material,
## named with the shader it runs, holding one entry per dial that shader declares. The frozen
## free-string Effects rows sit beside them on their own shelf, because they are still exactly right
## for a material that only exists at run time - a name nothing can check is a name nobody should be
## made to pretend was checked.
const EFFECTS_GROUP := "Effects in this scene"

## The picker category the effect rows are filed under.
const EFFECTS_CATEGORY := "Effects"

## The separator between a shelf entry's facts - the middle dot every other two-fact reading in the
## editor uses.
const SHELF_BULLET := "·"

## Simple Mode (the newcomer view) hides the advanced "drop to code" + debug ACEs from the picker,
## so beginners aren't shown Run GDScript / Evaluate / Breakpoint / Assert / Print Rich. Keyed by
## "provider_id::ace_id" (definition.id == the descriptor's ace_id - see ace_adapter.gd).
const _SIMPLE_MODE_DENYLIST := {
	"Core::RunGDScript": true,
	"Core::EvaluateGDScript": true,
	"Core::EvaluateExpression": true,
	"Core::Breakpoint": true,
	"Core::Assert": true,
	"Core::PrintRich": true,
}


static func favorite_ids() -> PackedStringArray:
	if ProjectSettings.has_setting(FAVORITES_SETTING):
		return PackedStringArray(ProjectSettings.get_setting(FAVORITES_SETTING))
	return PackedStringArray()


static func toggle_favorite(provider_id: String, ace_id: String) -> bool:
	var favorites: PackedStringArray = favorite_ids()
	var favorite_key: String = "%s/%s" % [provider_id, ace_id]
	var existing: int = favorites.find(favorite_key)
	if existing >= 0:
		favorites.remove_at(existing)
	else:
		favorites.append(favorite_key)
	ProjectSettings.set_setting(FAVORITES_SETTING, favorites if not favorites.is_empty() else null)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	return existing < 0


## True when `query`'s characters appear in order inside `text` (case/space-insensitive)
## - the power user's "stt" reflex from event-sheet/GDevelop pickers.
static func fuzzy_match(query: String, text: String) -> bool:
	var needle: String = query.to_lower().replace(" ", "")
	var haystack: String = text.to_lower().replace(" ", "")
	if needle.is_empty():
		return false
	var position: int = 0
	for character in needle:
		position = haystack.find(character, position)
		if position < 0:
			return false
		position += 1
	return true


## Records a use (newest first, deduped, capped) - drives the ★ Recent picker section, and survives
## an editor restart (persisted to the per-user recents file).
static func note_recent(provider_id: String, ace_id: String) -> void:
	load_recents()
	var recent_key: String = "%s/%s" % [provider_id, ace_id]
	var existing_recent: int = _recent_ace_ids.find(recent_key)
	if existing_recent >= 0:
		_recent_ace_ids.remove_at(existing_recent)
	_recent_ace_ids.insert(0, recent_key)
	if _recent_ace_ids.size() > RECENT_ACES_CAP:
		_recent_ace_ids.resize(RECENT_ACES_CAP)
	_save_recents()


## One recents entry per project, keyed by a hash of the project path, so a single editor's recents
## file never leaks ACEs between projects.
static func _recents_project_key() -> String:
	return ProjectSettings.globalize_path("res://").sha1_text()


## Hydrates this project's recents from the user:// file once per session (a no-op afterwards, and
## outside the editor where persistence is meaningless - keeps the headless suite side-effect-free).
static func load_recents() -> void:
	if _recents_loaded:
		return
	_recents_loaded = true
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(RECENTS_FILE) != OK:
		return
	var stored: Variant = config.get_value("recents", _recents_project_key(), PackedStringArray())
	if stored is PackedStringArray:
		_recent_ace_ids = stored


static func _save_recents() -> void:
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(RECENTS_FILE)  # preserve other projects' recents already in the file
	config.set_value("recents", _recents_project_key(), _recent_ace_ids)
	if config.save(RECENTS_FILE) != OK:
		push_warning("EventSheets: couldn't save picker recents to %s - they last only this session." % RECENTS_FILE)

## Node-type sections pre-declared at the top of the "Add Event" picker, in order.
const EVENT_PICKER_GROUPS: Array[String] = [
	"CharacterBody2D", "Area2D", "Node2D", "RigidBody2D", "Timer", "AnimationPlayer"
]

## Categories nest one level on this separator: "Variables: Array" renders as an Array
## folder inside the Variables section. Authors get a sub-section just by naming the
## category "Parent: Sub" - no schema change. Node-type sections never sub-nest.
const SUBCATEGORY_SEPARATOR: String = ": "

## Hand-picked icons for categories that DERIVATION cannot reach: abstract groupings whose name is
## not a class and whose verbs have no host node ("Math & Random", "General Actions", "Helpers").
## Everything else resolves automatically - see category_icon_name - so adding a category to the
## vocabulary does NOT mean editing a table here. Values are EditorIcons names; unknown names and
## headless runs degrade to no icon. Entries also OVERRIDE derivation, for the cases where a human
## choice beats the derived one (an "Overlap" section reads better as an Area than a bare Node).
const CATEGORY_EDITOR_ICONS: Dictionary = {
	# The three objects batch ten added. Each names the node its rows act on, which is
	# also the icon a reader already associates with that kind of row in the Scene dock.
	"AJAX": "HTTPRequest",
	"Lighting": "PointLight2D",
	"Video": "VideoStreamPlayer",
	"Animation": "AnimationPlayer",
	"Mesh": "MeshInstance3D",
	"Gradients & Curves": "Gradient",
	"Audio Server": "AudioBusLayout",
	"Physics Server": "PhysicsMaterial",
	"Behavior": "Node",
	# The four game-shape sections. None of their names is a class and none of
	# their verbs has a host node, which is exactly what this table is still for: a meter is a bar, a
	# stealth row is about being heard, a boss section is the fight itself, a mission is its clock.
	"Meters": "ProgressBar",
	"Stealth": "AudioStreamPlayer",
	"Boss": "GuiRadioUnchecked",
	"Missions": "Timer",
	# The rest of a level of that shape: the doors that gate it, the things in it that
	# come for you, and the things lying around that you pick up.
	"Keys & Doors": "Key",
	"Enemies 3D": "CharacterBody3D",
	"Pickups": "Area3D",
	"Collisions": "CollisionShape2D",
	"Color": "Color",
	# The one entry the five "Compare: …" sub-categories all inherit. Nothing derivable here: the name
	# is not a class and the verbs are host-agnostic, which is exactly what this table is still for.
	"Compare": "GuiChecked",
	"Debug": "NodeWarning",
	"Display": "Window",
	"Drawing": "CanvasItem",
	"Editor Tools": "Tools",
	"Effects": "Shader",
	"Files": "File",
	"Files: Directories": "Folder",
	"Functions": "MemberMethod",
	"Game Options": "Tools",
	"Game Window": "Window",
	"Gamepad": "InputEventJoypadButton",
	"General Actions": "Play",
	"General Conditions": "GuiChecked",
	"General Expressions": "Variant",
	"Groups": "Groups",
	"Helpers": "GDScript",
	"Input": "InputEvent",
	"InputMap": "InputEventAction",
	"Joints": "PinJoint2D",
	"Keyboard": "InputEventKey",
	"Loops": "Loop",
	"Math & Random": "RandomNumberGenerator",
	"Metadata": "Object",
	"Mouse": "InputEventMouseButton",
	"Movement": "Path2D",
	# Nothing derivable: "Multiplayer" is not a class, and the messages a peer sends are the
	# nearest thing the editor draws to what these rows are about.
	# The Browser is not a class, so nothing derives it: the rows there leave the game (a link, the
	# clipboard, the window mode), and the editor's own "this opens somewhere else" mark says that.
	"Browser": "ExternalLink",
	"Multiplayer": "Signals",
	"Nodes": "Node",
	"Overlap 2D": "Area2D",
	"Overlap 3D": "Area3D",
	"Platform": "Godot",
	"Procedural": "FastNoiseLite",
	"Rendering": "Environment",
	"Run Context": "PlayScene",
	"Scene": "PackedScene",
	"Signals / Scene / Input": "Signals",
	"Systems": "Groups",
	# The player-facing accessibility options. Godot has no icon for the idea, so the row that
	# every one of them ends up on - a setting the player changes - lends its own.
	"Accessibility": "GuiRadioCheckedDisabled",
	# A Test sheet's claims: the name is not a class and the verbs record onto the test node rather
	# than driving one, so derivation cannot reach it. The tick reads as pass/fail, which is what a
	# claim is.
	"Testing": "GuiChecked",
	"Timed Input": "Timer",
	"Text": "String",
	"Time": "Timer",
	"Touch": "InputEventScreenTouch",
	"Utility": "Tools",
	"Variables": "MemberProperty",
	"Variables: Array": "Array",
	"Variables: Dictionary": "Dictionary",
	"Variables: String": "String",
	"Variables: Vector": "Vector2",
	"Vibration": "InputEventJoypadMotion",
	"Weapons 3D": "RayCast3D",
}

# Group-header colours (by group kind).
const GROUP_COLOR_NODE_TYPE := Color("#e0b070")  # amber - Godot class sections
const GROUP_COLOR_CUSTOM := Color("#c79bf0")      # purple - custom / runtime providers
const GROUP_COLOR_NEUTRAL := Color("#9aa1ad")     # neutral muted - other categories
# Used by the ƒx expression autocomplete (ace_params_dialog) to tint expression fragments. The ACE
# picker itself no longer tints rows by type (Create-New-Node style - the per-row icon carries that).
const ITEM_COLOR_EXPRESSION := Color("#c79bf0") # soft purple

var _window: ConfirmationDialog = null
var _search: LineEdit = null
# Object-first front page state: the object tree, its holder page, the breadcrumb back
# button, the classic body's holder (to swap visibility), and the provider scope ("" = all).
var _objects_page: Control = null
var _objects_tree: Tree = null
var _objects_back: Button = null
var _body_holder: Control = null
var _object_filter_provider: String = ""
var _tree: Tree = null
var _info_label: RichTextLabel = null
var _info_panel: PanelContainer = null
## The live one-row illustration of the highlighted verb, built from its parameter defaults.
var _guide_button: Button = null
## Returns the label for the highlighted verb's "read more" affordance ("Open Quest's guide"), or
## "" for no affordance. Phase 2 of the docs work wires it to the derived pack -> guide mapping;
## unset, the button simply never appears.
var _guide_label_provider: Callable = Callable()
var _favorites_list: Tree = null
var _recent_list: Tree = null
var _favorite_button: Button = null
var _add_button: Button = null
var _selected_definition: ACEDefinition = null
## True while the highlighted entry is the Add event dialog's "(none - runs every tick)" row,
## which carries no definition of its own. Add / Enter commit a blank event while it is set.
var _blank_event_highlighted: bool = false
var _tree_context_menu: PopupMenu = null
var _tree_context_definition: ACEDefinition = null
var _hint: Label = null
var _context: Dictionary = {}
var _registry: EventSheetACERegistry = null


## Initialise and attach the picker window to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node, registry: EventSheetACERegistry) -> void:
	_registry = registry
	# The node the picker hangs on IS the dock, and the dock owns the open sheet - so the Functions
	# page reads `get_current_sheet()` off it directly and follows the active tab with no extra
	# wiring to keep in sync.
	_host_node = parent_node
	load_recents()  # hydrate this project's persisted recents before the ★ Recent pane first draws
	if _window != null:
		return
	# A ConfirmationDialog (not a bare Window) so the picker gets the same editor-themed panel,
	# title bar, and OK/Cancel buttons as every other plugin dialog (function / variable / params).
	# The built-in OK button is the "Add" button; Cancel is the dialog's own cancel button.
	_window = ConfirmationDialog.new()
	_window.title = "Add Action / Condition"
	_window.visible = false
	_window.min_size = Vector2i(640, 420)
	_window.ok_button_text = "Add"
	_window.close_requested.connect(close)
	_window.canceled.connect(close)
	_window.confirmed.connect(_on_add_button_pressed)
	parent_node.add_child(_window)
	# The dialog's own OK button drives "Add" - disabled until something is selected.
	_add_button = _window.get_ok_button()
	_add_button.disabled = true

	# A sensible default content width; the body height is bounded by the split below so the
	# dialog opens at a comfortable size and the tree scrolls internally (it does NOT grow to
	# fit every row - a ConfirmationDialog otherwise hugs its content's full minimum height).
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.custom_minimum_size = Vector2(700.0, 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.add_child(EventSheetPopupUI.margined(content))

	# Search row: the field + a ⭐ toggle that pins/unpins the highlighted ACE.
	var search_row: HBoxContainer = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	content.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "ACEPickerSearch"
	_search.placeholder_text = "Search actions, conditions, triggers..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void:
		# Typing on the object-cards page drops straight into classic full search - the
		# fast path stays fast, cards are for browsing.
		if _objects_page != null and _objects_page.visible and not _text.strip_edges().is_empty():
			_object_filter_provider = ""
			_show_classic(false)
		_refresh_tree()
		_select_first_match())
	_search.text_submitted.connect(func(_text: String) -> void: _activate_first_match())
	_search.gui_input.connect(_on_search_gui_input)
	search_row.add_child(_search)
	_favorite_button = Button.new()
	_favorite_button.toggle_mode = true
	_favorite_button.text = "⭐"
	_favorite_button.tooltip_text = "Pin the highlighted entry to Favorites (or right-click any entry)."
	_favorite_button.focus_mode = Control.FOCUS_NONE
	_favorite_button.pressed.connect(_on_favorite_button_pressed)
	search_row.add_child(_favorite_button)

	# Single-line (NOT autowrap): the dialog sizes to its content's minimum, and an autowrap
	# label reports a runaway min height during the initial zero-width pass (it wraps to one
	# glyph per line), which balloons the whole dialog. The hints are short, fixed strings that
	# fit the dialog width, so a single line is all they need.
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(_hint)

	# Body: ⭐ Favorites + ★ Recent panes on the left (Create-Node style), category tree right.
	# A plain Control holder bounds the dialog height: a Tree reports its FULL content height as
	# its minimum size, and a ConfirmationDialog grows to fit that - so a populated picker would
	# open thousands of px tall. A bare Control ignores its children's minimums and reports only
	# its own, so the split fills it (anchored) and the trees scroll internally at a fixed height.
	var body_holder: Control = Control.new()
	# Object-first front page (the event-sheet add-event gesture): big object cards - System,
	# the host's behaviors, packs, autoloads - shown before the category tree when the picker
	# opens from a double-click on empty canvas. Picking a card scopes the tree to that
	# object's vocabulary; typing anything drops straight into classic full search.
	# The object list is a Tree styled exactly like the classic category tree - section
	# headers, SMALL native-size icons beside the text, row selection - so the object-first
	# step looks and handles like the rest of this picker (single-click an object to browse
	# its verbs; icons stay 16px, never scaled up).
	_objects_page = Control.new()
	_objects_page.custom_minimum_size = Vector2(0.0, 452.0)
	_objects_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objects_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_objects_page.visible = false
	_objects_tree = Tree.new()
	_objects_tree.hide_root = true
	_objects_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_objects_tree.item_selected.connect(_on_object_tree_selected)
	_objects_page.add_child(_objects_tree)
	content.add_child(_objects_page)
	_objects_back = Button.new()
	_objects_back.text = "◂ All objects"
	_objects_back.visible = false
	_objects_back.focus_mode = Control.FOCUS_NONE
	_objects_back.pressed.connect(func() -> void:
		_object_filter_provider = ""
		_show_objects_page())
	content.add_child(_objects_back)
	body_holder.custom_minimum_size = Vector2(0.0, 340.0)
	body_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body_holder)
	_body_holder = body_holder
	var split: HSplitContainer = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 200
	body_holder.add_child(split)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(190.0, 0.0)
	side.add_theme_constant_override("separation", 8)
	split.add_child(side)
	var favorites_label: Label = Label.new()
	favorites_label.text = "⭐ Favorites"
	favorites_label.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	_favorites_list = _make_side_tree()
	var favorites_card: PanelContainer = EventSheetPopupUI.panel_section(_titled_pane(favorites_label, _favorites_list))
	favorites_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(favorites_card)
	var recent_label: Label = Label.new()
	recent_label.text = "★ Recent"
	recent_label.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	_recent_list = _make_side_tree()
	var recent_card: PanelContainer = EventSheetPopupUI.panel_section(_titled_pane(recent_label, _recent_list))
	recent_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(recent_card)
	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	# Single muted column (Godot Create-New-Node style): type is conveyed by the per-row icon + the
	# tooltip + the description panel, so the old "Type" column and per-row type tint were redundant noise.
	_tree.columns = 1
	_tree.set_column_titles_visible(false)
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_selected.connect(_on_item_selected_for_info)
	_tree.gui_input.connect(_on_tree_gui_input)
	_tree.button_clicked.connect(_on_tree_button_clicked)
	split.add_child(_tree)
	# Description panel (Create-Node style): the highlighted ACE's name, type + what it does.
	# Fixed height + internal scrolling (NOT fit_content): inside a ConfirmationDialog the dialog
	# hugs its content's minimum size, and a fit_content + autowrap RichTextLabel reports a huge
	# min height during that pass (it wraps at ~0 width), which would balloon the whole dialog.
	_info_panel = PanelContainer.new()
	# Same filled inset card as the Favorites/Recent panes, so the description reads as a distinct panel.
	_info_panel.add_theme_stylebox_override("panel", EventSheetPopupUI.inset_panel_stylebox())
	# Tall enough for name + description + the "ships as" codegen line without scrolling - the
	# description panel is the picker's main teaching surface, so it gets room to breathe.
	_info_panel.custom_minimum_size = Vector2(0.0, 110.0)
	content.add_child(_info_panel)
	var info_margin: MarginContainer = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_top", 6)
	info_margin.add_theme_constant_override("margin_bottom", 6)
	_info_panel.add_child(info_margin)
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = false
	_info_label.scroll_active = true
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_margin.add_child(_info_label)
	# The read-more affordance for a pack verb ("Open Quest's guide"), a slim right-aligned link
	# under the description. It is the only extra the picker carries: the description panel already
	# says what the verb is, and a live figure here read as clutter, so the illustration lives in the
	# Explain panel (F1 / right-click a row), where a reader has asked to be shown.
	var guide_row: HBoxContainer = HBoxContainer.new()
	guide_row.alignment = BoxContainer.ALIGNMENT_END
	_guide_button = Button.new()
	_guide_button.flat = true
	_guide_button.visible = false
	_guide_button.pressed.connect(_on_figure_guide_requested)
	guide_row.add_child(_guide_button)
	content.add_child(guide_row)
	# Add / Cancel are the dialog's own themed buttons (wired in the window setup above);
	# double-click and Enter-to-add still work alongside them.

## Provider returning true when Simple Mode is on (wired by the dock) - gates the denylist below.
var _simple_mode_provider: Callable = Callable()
## Returns the class name whose reflected "All of <Class>" section the picker
## should offer (the current sheet's host class); invalid = no reflection.
var _reflect_class_provider: Callable = Callable()
## Returns whether the current sheet is a behaviour (its `host` var exists); gates the host-only ACEs.
var _behavior_mode_provider: Callable = Callable()
## Returns whether the current sheet runs in the editor (`tool_mode`); gates the Editor object.
var _tool_mode_provider: Callable = Callable()
## The node the dialog was attached to (the dock). Only read for the open sheet, never held onto.
var _host_node: Node = null
## Returns the open sheet's variables as EventSheetVariableOwners entries. Unset = the Variables
## group reads exactly as it always did, so an embedder that never wires it loses nothing.
var _variable_catalog_provider: Callable = Callable()
## Derived once per open (the provider reads the autoloads' scripts), cleared by open().
var _variable_catalog: Array[Dictionary] = []


func set_simple_mode_provider(provider: Callable) -> void:
	_simple_mode_provider = provider


## The sheet's variables, so the Variables group can name the ones each verb can take and the
## description panel can read their sentence. A `-> Array[Dictionary]` of catalog entries.
func set_variable_catalog_provider(provider: Callable) -> void:
	_variable_catalog_provider = provider


## The catalog behind the open dialog, derived at most once per open.
func _variables_in_scope() -> Array[Dictionary]:
	if _variable_catalog.is_empty() and _variable_catalog_provider.is_valid():
		var provided: Variant = _variable_catalog_provider.call()
		if provided is Array:
			for entry: Variant in (provided as Array):
				if entry is Dictionary:
					_variable_catalog.append(entry as Dictionary)
	return _variable_catalog


## The names a Variables verb can take, written beside it: "hp, speed", "nothing of that kind
## yet" when the sheet has none, and "" for every verb that is not one of the seven.
static func variable_verb_note(entries: Array[Dictionary], definition: ACEDefinition) -> String:
	if definition == null or definition.category != VARIABLES_CATEGORY:
		return ""
	if not EventSheetVariableOwners.VARIABLE_VERB_ORDER.has(str(definition.id)):
		return ""
	var names: String = EventSheetVariableOwners.verb_variable_note(entries, str(definition.id))
	return names if not names.is_empty() else EventSheetL10n.translate("nothing of that kind yet")


func set_reflect_class_provider(provider: Callable) -> void:
	_reflect_class_provider = provider


## The behaviour-only host vocabulary (Host / Host Is Valid) reads the literal `host` var, which only
## exists in a behaviour sheet's synthesized prelude. The dock feeds this a `-> bool` that is true when
## the current sheet is a behaviour, so the picker hides those ACEs off a plain / resource / node sheet.
func set_behavior_mode_provider(provider: Callable) -> void:
	_behavior_mode_provider = provider


## The same shape for the Editor object: a `-> bool` that is true when the open sheet runs in the
## editor at all (a Tool sheet, or any sheet with Tool ticked). Without a provider the gate is off, so
## an embedder that never wires it keeps the vocabulary it always had.
func set_tool_mode_provider(provider: Callable) -> void:
	_tool_mode_provider = provider


## True when a definition is a behaviour-only host ACE that must NOT be offered on a non-behaviour sheet
## (it would emit an undefined `host`). Pure + static so the gate is unit-testable without a live picker.
static func host_ace_hidden(provider_id: String, ace_id: String, is_behavior_sheet: bool) -> bool:
	return not is_behavior_sheet and provider_id == "Core" and ace_id in ["BehaviorHost", "BehaviorHostValid"]


## The Editor object's whole category. Every one of those rows calls EditorInterface or an
## EditorPlugin method, which exist only in the editor process - offered on a Player sheet they are
## rows that cannot run, so the picker scopes the object to @tool sheets the way it scopes Functions
## to the open script. Pure + static so the gate is unit-testable without a live picker.
static func editor_ace_hidden(category: String, is_tool_sheet: bool) -> bool:
	return not is_tool_sheet and is_editor_tools_category(category)


## The Editor object grew PAGES - "Editor Tools: Panels & menus", "Editor Tools: Project &
## preferences" and the rest - which the picker nests one level in on the ": " separator. A page is
## still the Editor object, so every gate that used to compare the whole category asks here instead;
## comparing on equality would have quietly un-scoped every paged row onto game sheets.
static func is_editor_tools_category(category: String) -> bool:
	return category == EDITOR_TOOLS_CATEGORY or category.begins_with(EDITOR_TOOLS_CATEGORY + SUBCATEGORY_SEPARATOR)


## The one category the gate above reads. Named here rather than spelled at the call site because it
## is also what the vocabulary files put on every Editor descriptor.
const EDITOR_TOOLS_CATEGORY := "Editor Tools"

## The picker category the variable verbs are filed under. Frozen with their descriptors.
const VARIABLES_CATEGORY := "Variables"

## Where the picker files every comparison the Compare dialog owns EXCEPT the lead one: a single
## sub-folder under Variables, so "how do I compare something" is one entry rather than twelve rows
## scattered across General Conditions, Text and Numbers. The DESCRIPTORS keep their own categories
## (their ids, templates and their place in the vocabulary doc are untouched) - this is only where
## the picker puts them, and searching still finds each by its own name.
const COMPARISONS_GROUP := VARIABLES_CATEGORY + SUBCATEGORY_SEPARATOR + "All comparisons"


## The picker group a comparison belongs in, or "" for anything that is not one. The lead
## comparison (Compare variable) stays in the owner's own group beside Set value and Is boolean set,
## because comparing a variable is the question people come to that group for; every other
## comparison files under the one sub-folder. Pure + static, so the filing is pinned without a tree.
static func comparison_group_key(definition: ACEDefinition) -> String:
	if definition == null or definition.provider_id != EventSheetCompareConditionDialog.PROVIDER:
		return ""
	if definition.id == EventSheetCompareConditionDialog.ACE_COMPARE_VAR:
		return ""
	return COMPARISONS_GROUP if EventSheetCompareConditionDialog.COMPARE_ACE_IDS.has(definition.id) else ""


## Which shelf of the Multiplayer object a TRIGGER is offered on, or "" for anything else -
## every action, condition and expression there stays in the one flat section, and so does every
## row of every other object. Derived from the trigger itself rather than listed: a trigger that
## names a node in the scene is about that node (Scenes), one that hands you a player id is about a
## player (Players), and one that says only what happened to this peer's own connection is about the
## connection. A trigger added to the vocabulary later is filed by the same three questions, with no
## table to remember to edit. Pure + static, so the filing is pinned without a tree.
static func multiplayer_group_key(definition: ACEDefinition) -> String:
	if definition == null or definition.ace_type != ACEDefinition.ACEType.TRIGGER:
		return ""
	if definition.category.strip_edges() != EventForgeMultiplayerACEs.CATEGORY:
		return ""
	if not str(definition.metadata.get("node_type", "")).strip_edges().is_empty():
		return EventForgeMultiplayerACEs.SECTION_SCENES
	if definition.parameters.is_empty():
		return EventForgeMultiplayerACEs.SECTION_CONNECTION
	return EventForgeMultiplayerACEs.SECTION_PLAYERS


## The shelf a scene-lighting row is offered on, or "" for everything else - including the
## same verb browsed under its own class, which stays where it was. Outranks the node-type filing for
## the same reason the comparisons and the Multiplayer shelves do: what a row IS beats where it was
## filed. Pure + static, so the filing is pinned without a tree.
static func scene_lighting_group_key(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var shelf: String = str(definition.metadata.get(SCENE_SHELF_META, "")).strip_edges()
	if shelf.is_empty():
		return ""
	var group: String = str(definition.metadata.get(SCENE_GROUP_META, LIGHTS_GROUP)).strip_edges()
	return group + SUBCATEGORY_SEPARATOR + shelf


## Every row the OPEN SCENE's own lighting nodes can take, as picker entries: one copy per
## node per verb its class answers to, with the node already chosen. Which verbs a node can take is
## derived - a row hosted on a class that node inherits - so a SpotLight3D is offered the Light3D
## words and its own cone angle, and a WorldEnvironment the atmosphere words, without either being
## listed anywhere.
##
## Pure + static (a sheet and a registry in, definitions out), so the shelves are pinned headless.
static func scene_lighting_definitions(sheet: EventSheetResource, registry: EventSheetACERegistry) -> Array[ACEDefinition]:
	var out: Array[ACEDefinition] = []
	if sheet == null or registry == null:
		return out
	for shelf_kind: Dictionary in SCENE_SHELVES:
		var root: String = str(shelf_kind["root"])
		var nodes: Array[Dictionary] = _scene_lighting_nodes(str(sheet.external_source_path), root)
		if nodes.is_empty():
			continue
		# The registry is walked ONCE per shelf, not once per node: this runs on every keystroke of
		# the search box, and a room with thirty torches was thirty full walks of the vocabulary per
		# character typed. Which verbs a shelf offers depends only on its class, so the answer is the
		# same for every node on it.
		var vocabulary: Array[ACEDefinition] = _shelf_vocabulary(registry, root)
		for node: Dictionary in nodes:
			var shelf: String = scene_node_shelf_label(node)
			for definition: ACEDefinition in vocabulary:
				if not ClassDB.is_parent_class(str(node["class"]),
						str(definition.metadata.get("node_type", ""))):
					continue
				# copy(), never duplicate(): an ACEDefinition's fields are plain vars, so
				# duplicate() would hand back a blank definition that still looks valid.
				var offered: ACEDefinition = definition.copy()
				offered.metadata[SCENE_TARGET_META] = str(node["reference"])
				offered.metadata[SCENE_SHELF_META] = shelf
				offered.metadata[SCENE_GROUP_META] = str(shelf_kind["group"])
				out.append(offered)
	return out


## The verbs one shelf can offer at all - the registry's node-scoped rows whose host class belongs on
## a shelf of this class. Which of them a particular NODE takes is the narrower question above.
static func _shelf_vocabulary(registry: EventSheetACERegistry, root: String) -> Array[ACEDefinition]:
	var offered: Array[ACEDefinition] = []
	for definition: ACEDefinition in registry.get_all_definitions():
		if _shelf_offers(str(definition.metadata.get("node_type", "")), root):
			offered.append(definition)
	return offered


## The nodes one shelf is about: every light of the scene when the shelf names no class, and the
## nodes of that class when it does.
static func _scene_lighting_nodes(source_path: String, root: String) -> Array[Dictionary]:
	if root.is_empty():
		return EventSheetSceneLights.for_script(source_path)
	return EventSheetSceneLights.nodes_of_class(source_path, root)


## True when a verb hosted on `node_type` belongs on a shelf whose own class is `root` - any light
## for the lights shelf, that class or a subclass of it for the other two.
static func _shelf_offers(node_type: String, root: String) -> bool:
	if node_type.strip_edges().is_empty():
		return false
	if root.is_empty():
		return EventForgeLightWords.is_light_class(node_type)
	return ClassDB.class_exists(node_type) and ClassDB.is_parent_class(node_type, root)


## The shelf an EFFECT row is offered on, or "" for everything else. A row built for one dial of one
## node goes under that node; the frozen free-string rows go on the general shelf beside them, and
## only while the sheet has dial shelves at all - a project with no shaders keeps its picker exactly
## as it was. Pure + static, so the filing is pinned without a tree.
static func effect_group_key(definition: ACEDefinition, has_dial_shelves: bool) -> String:
	if definition == null:
		return ""
	var shelf: String = str(definition.metadata.get(SCENE_SHELF_META, "")).strip_edges()
	if str(definition.metadata.get(SCENE_GROUP_META, "")) == EFFECTS_GROUP and not shelf.is_empty():
		return EFFECTS_GROUP + SUBCATEGORY_SEPARATOR + shelf
	if not has_dial_shelves or definition.category.strip_edges() != EFFECTS_CATEGORY:
		return ""
	return EFFECTS_GROUP + SUBCATEGORY_SEPARATOR \
		+ EventSheetL10n.translate("any material, name typed")


## Every row the OPEN SCENE's own shader materials can take, as picker entries: one copy per node per
## dial per verb, with the node AND the dial already chosen, so the params dialog opens on the value.
## Which dials a node has is the shader's answer, walked once by EventSheetSceneEffects - nothing here
## knows a dial name, which is the whole point of the vocabulary.
##
## Pure + static (a sheet and a registry in, definitions out), so the shelves are pinned headless.
static func effect_dial_definitions(sheet: EventSheetResource, registry: EventSheetACERegistry) -> Array[ACEDefinition]:
	var out: Array[ACEDefinition] = []
	if sheet == null or registry == null:
		return out
	# The registry is walked ONCE, not once per node or per dial: this runs on every keystroke of the
	# search box, and a scene with thirty dials was thirty full walks of the vocabulary per character.
	var vocabulary: Array[ACEDefinition] = []
	for definition: ACEDefinition in registry.get_all_definitions():
		if bool(definition.metadata.get("project_scoped", false)) \
				and definition.category.strip_edges() == EFFECTS_CATEGORY:
			vocabulary.append(definition)
	for node: Dictionary in EventSheetSceneEffects.for_script(str(sheet.external_source_path)):
		var shelf: String = scene_effect_shelf_label(node)
		for entry: Variant in node.get("dials", []):
			var dial: Dictionary = entry
			for definition: ACEDefinition in vocabulary:
				out.append(_dial_entry(definition, node, dial, shelf))
	return out


## One dial's line on the shelf: the node it belongs to and the shader file it runs, which together
## are what a reader arrived asking about ("which of MY effects", and which shader is behind it).
static func scene_effect_shelf_label(node: Dictionary) -> String:
	return "%s   %s" % [str(node.get("name", "")), str(node.get("shader_path", "")).get_file()]


## One picker entry: the shipped row with the node and the dial answered, named with the dial FIRST
## because that is what a reader scans for, and described with what the shader itself says about it.
static func _dial_entry(definition: ACEDefinition, node: Dictionary, dial: Dictionary,
		shelf: String) -> ACEDefinition:
	# copy(), never duplicate(): an ACEDefinition's fields are plain vars, so duplicate() would hand
	# back a blank definition that still looks valid.
	var offered: ACEDefinition = definition.copy()
	var dial_name: String = str(dial.get("name", ""))
	offered.display_name = "%s  %s  %s" % [EventForgeValueLens.effect_dial(dial_name), SHELF_BULLET,
		EventSheetL10n.translate(definition.display_name)]
	offered.description = effect_dial_description(dial, definition.description)
	offered.metadata[SCENE_TARGET_META] = str(node.get("reference", ""))
	offered.metadata[SCENE_SHELF_META] = shelf
	offered.metadata[SCENE_GROUP_META] = EFFECTS_GROUP
	offered.metadata[SCENE_PREFILL_META] = {EventForgeEffectDialACEs.DIAL_PARAM: dial_name}
	return offered


## What one dial's entry says about itself: the shader author's own `//` comment when they wrote one,
## then the declaration read back (the type, the ends of its range, what it starts at), then the
## row's own description. The first two come out of the shader file, so a reader is told what this
## particular dial is rather than what dials are.
static func effect_dial_description(dial: Dictionary, row_description: String) -> String:
	var said: PackedStringArray = PackedStringArray()
	var about: String = str(dial.get("about", "")).strip_edges()
	if not about.is_empty():
		said.append(about)
	said.append(EventForgeShaderUniforms.reading(dial))
	said.append(row_description)
	return " ".join(said)


## One node's line on the shelf: its name, the class it is, and - for a light - whether it
## casts shadows. The facts that decide which row a reader wants and whether it will do anything.
static func scene_node_shelf_label(node: Dictionary) -> String:
	var label: String = "%s   %s" % [str(node.get("name", "")), str(node.get("class", ""))]
	if bool(node.get("shadows", false)):
		label += " %s %s" % [SHELF_BULLET, EventSheetL10n.translate("casts shadows")]
	return label


## Update the registry used for searching (e.g. after a hot-reload).
func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry


## Open the picker for the given mode.
## Selects + reveals the entry for an ace id - the double-click-to-replace flow
## opens the picker focused on what's being replaced. Ancestors expand first:
## selecting inside a collapsed group is invisible, which reads as "not selected".
func preselect(ace_id: String) -> void:
	if _tree == null or ace_id.is_empty():
		return
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		if item == null:
			continue
		var item_meta: Variant = item.get_metadata(0)
		if item_meta is ACEDefinition and (item_meta as ACEDefinition).id == ace_id:
			var ancestor: TreeItem = item.get_parent()
			while ancestor != null:
				ancestor.collapsed = false
				ancestor = ancestor.get_parent()
			item.select(0)
			_tree.scroll_to_item(item)
			return
		stack.push_back(item.get_next())
		stack.push_back(item.get_first_child())


## mode: "new_event" | "new_condition_event" | "new_sub_condition_event" | "append_condition"
##       | "append_action" | "replace_condition" | "replace_action" | "replace_trigger"
## signals_only: restrict results to signal triggers
## selected_resource: the currently selected EventRow (for context passing)
func open(mode: String, signals_only: bool, selected_resource: Resource, extra_context: Dictionary = {}) -> void:
	if _window == null:
		push_error("ACEPickerDialog.open() called before init_dialog().")
		return
	_context = {
		"mode": mode,
		"signals_only": signals_only,
		"selected_resource": selected_resource
	}
	for key in extra_context.keys():
		_context[key] = extra_context[key]
	# The variables in scope, re-derived per open (a variable may have been added since) and
	# never per keystroke: the answer reads the autoloads' scripts off disk.
	_variable_catalog.clear()
	_object_filter_provider = ""
	# "Add condition on Player" opens the picker ALREADY on Player: the object step of the
	# two-step pick is answered, so the dialog opens at the verbs for that object rather than at the
	# object cards the caller has just chosen from.
	var scoped_object: String = str(_context.get("object_scope", "")).strip_edges()
	if not scoped_object.is_empty():
		_object_filter_provider = scoped_object
		if _objects_back != null:
			_objects_back.text = "◂ %s · %s" % [
				EventSheetL10n.translate("All objects"), str(_context.get("object_label", scoped_object))
			]
		_show_classic(true)
	elif bool(_context.get("object_first", false)) and not signals_only and mode in ["new_event", "new_condition_event", "new_sub_condition_event"]:
		_show_objects_page()
	else:
		_show_classic(false)
	var title: String = _title_for_mode(mode, signals_only)
	_window.title = title
	_search.text = ""
	_hint.text = _build_hint_text(mode, signals_only)
	_selected_definition = null
	if _add_button != null:
		_add_button.disabled = true
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(false)
	_update_info_panel(null)
	_refresh_tree()
	_refresh_side_panes()
	_select_first_match()
	_window.popup_centered(Vector2i(720, 520))
	_window.grab_focus()
	_search.grab_focus()
	# Deferred so it lands AFTER the popup and any visibility-driven refresh -
	# callers preselect via context instead of racing the open sequence.
	if _context.has("preselect_ace_id"):
		call_deferred("preselect", str(_context.get("preselect_ace_id")))


func _title_for_mode(mode: String, signals_only: bool) -> String:
	if signals_only:
		return "Add Event"
	match mode:
		"new_event", "new_condition_event":
			return "Add Event"
		"new_sub_condition_event":
			return "Add Sub-Event"
		"append_condition":
			return "Add Condition"
		"append_action":
			return "Add Action"
		"replace_condition":
			return "Replace Condition"
		"replace_trigger":
			return "Replace Trigger"
		"replace_action":
			return "Replace Action"
		_:
			return "Add Event"


func _build_hint_text(mode: String, signals_only: bool) -> String:
	if signals_only:
		return "Select a signal trigger to create a signal event."
	match mode:
		"new_condition_event":
			return "Select a condition or trigger to create a new event."
		"new_sub_condition_event":
			return "Select a condition or trigger to create a nested sub-condition event."
		"append_condition":
			return "Select a condition or trigger to append to the selected event."
		"append_action":
			return "Select an action to append to the selected event."
		"replace_condition":
			return "Select a condition to replace the current condition."
		"replace_trigger":
			return "Select a trigger to replace the current trigger."
		"replace_action":
			return "Select an action to replace the current action."
		_:
			return "Select a condition, action, or trigger to create a new event."

## Event-sheet phrase → Godot search-term bridge, so event-sheet users typing their old vocabulary
## still find the right ACE (e.g. "on start of layout" finds _ready-based triggers).
## The five variable verbs and the two questions, by the names everyone who has used an event
## sheet already says. Two of them are not descriptors of their own: "Set boolean" IS Set value with
## the value already filled in, and "Boolean is true / is false" IS Compare variable with `== true`.
## Minting a descriptor for each would put two templates in the lifter that match the same line -
## a previous attempt at exactly that stole every `muted = true` line from Set value - so they are
## ALIAS ROWS instead: the same frozen ace_id, the same emitted code, a different name in the picker
## and a form that opens already answering the boolean half of the question.
const VARIABLE_ALIASES: Array[Dictionary] = [
	{
		"display": "Set boolean",
		"provider": "Core",
		"ace_id": "SetVar",
		"prefill": {"value": "true"},
		"search": "set boolean toggle true false flag"
	},
	{
		"display": "Boolean is true / is false",
		"provider": "Core",
		"ace_id": "CompareVar",
		"prefill": {"op": "==", "value": "true"},
		"search": "boolean is true is false flag alive muted"
	}
]

## The prefill the alias row that was activated wants merged into the params dialog. Held for the
## single hop between the click and _commit_definition, and cleared there - an alias must never
## leave a value stuck on the ordinary row that shares its descriptor.
var _pending_alias_prefill: Dictionary = {}

const SEARCH_SYNONYMS := {
	"on start of layout": "ready",
	"start of layout": "ready",
	"every tick": "process",
	# Familiar Self.* property names whose Godot spelling genuinely differs (the Self expression
	# section's alias table carries the full list; these bridge the MAIN picker's search too).
	"angle": "rotation",
	"opacity": "modulate",
	"on created": "ready",
	"spawn": "instantiate",
	"create object": "instantiate",
	"destroy": "queue_free",
	"on collision": "body_entered",
	"is overlapping": "overlap",
	"set position": "position",
	"compare variable": "variable",
	# The two alias names, so the quick-add bar finds the descriptor they stand for even
	# though neither is a descriptor of its own.
	"set boolean": "set value",
	"boolean is true": "compare variable",
	"boolean is false": "compare variable",
	"wait": "timer",
	"go to layout": "scene",
	"goto layout": "scene",
	"restart layout": "restart",
	"choose": "choose",
	"pick random": "random",
	"set text": "text",
	"play sound": "play",
	"play audio": "play",
	"flash": "flash",
	"fade": "tween",
	"animate": "tween",
	"pathfinding": "path",
	"find path": "path",
	"set invisible": "hide",
	"set visible": "show",
	"set opacity": "tint",
	"time scale": "time scale",
	"tokenat": "token",
	"zeropad": "zero pad",
	"fullscreen": "fullscreen",
	"compare two values": "compare values",
	"is between": "between",
	"key is down": "key",
	"on key pressed": "key pressed",
	"mouse button is down": "mouse button",
	"cursor": "mouse",
	"gamepad": "gamepad",
	"is in touch": "touch",
	"on any touch start": "on touch",
	"vibrate": "vibrate",
	"play music": "play file",
	"set master volume": "bus volume",
	"audio": "audio",
	"playback time": "playback position",
}


## Extension synonyms (EventSheets.register_quick_add_synonyms): packs teach their own phrases
## on top of the built-in table. Session-scoped - re-register on plugin load.
static var _extra_synonyms: Dictionary = {}


static func register_synonyms(synonyms: Dictionary) -> void:
	for phrase: Variant in synonyms:
		_extra_synonyms[str(phrase).to_lower()] = str(synonyms[phrase])


static func _c3_synonym_queries(query: String) -> Array[String]:
	var lowered: String = query.to_lower().strip_edges()
	var extra: Array[String] = []
	if lowered.length() < 4:
		return extra
	for table: Dictionary in [SEARCH_SYNONYMS, _extra_synonyms]:
		for phrase: String in table:
			if lowered.contains(phrase) or phrase.contains(lowered):
				var mapped: String = str(table[phrase])
				if not extra.has(mapped):
					extra.append(mapped)
	return extra


## Shows the object-cards front page (and hides the tree) - the event-sheet "pick the object
## first" step. Cards enumerate live from the registry so new packs appear untouched.
func _show_objects_page() -> void:
	if _objects_page == null:
		return
	_populate_object_cards()
	_objects_page.visible = true
	_objects_back.visible = false
	if _body_holder != null:
		_body_holder.visible = false
	if _info_panel != null:
		_info_panel.visible = false


## Shows the classic search + tree; with a provider scope active the breadcrumb offers
## the way back to the cards.
func _show_classic(show_breadcrumb: bool) -> void:
	if _objects_page != null:
		_objects_page.visible = false
	if _objects_back != null:
		_objects_back.visible = show_breadcrumb
	if _body_holder != null:
		_body_holder.visible = true
	if _info_panel != null:
		_info_panel.visible = true


## The distinct "objects" the front page offers, from an assembled definitions list:
## one card per provider, Core folded into a leading "System" card (the event-sheet convention).
## Pure and static so tests pin the enumeration.
static func object_cards_for(definitions: Array[ACEDefinition]) -> Array[Dictionary]:
	var seen: Dictionary = {}
	var cards: Array[Dictionary] = []
	for definition: ACEDefinition in definitions:
		var provider: String = str(definition.provider_id)
		if provider.is_empty() or seen.has(provider):
			continue
		seen[provider] = true
		cards.append({"provider": provider, "label": "System" if provider == "Core" else provider})
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# System leads; the rest alphabetize - the stable order hands learn.
		if str(a.get("provider")) == "Core":
			return true
		if str(b.get("provider")) == "Core":
			return false
		return str(a.get("label")) < str(b.get("label")))
	return cards


## The open sheet, when there is a dock to read it off. Null everywhere else (a bare picker in a
## test, a headless run), which is exactly what the Functions page and the Lights shelf both treat
## as "no script open".
func _open_sheet() -> EventSheetResource:
	if _host_node == null or not _host_node.has_method("get_current_sheet"):
		return null
	return _host_node.get_current_sheet() as EventSheetResource


## The picker's Functions page for a sheet opened FROM a .gd: every function that file declares,
## the published verbs first and the plain helpers folded under their own header. Helpers are
## listed rather than hidden - they are functions of the same script and calling one is a normal
## thing to do - but each entry says it was never published as an ACE.
##
## Pure + static (no Tree, no icons, no editor theme), so a test reads exactly what the page says
## and a headless run builds it without a display. Returns {} when there is nothing to show: no
## sheet, no .gd behind it, or a file that declares no functions.
##
## Shape: {"title", "note", "helpers_header", "published": [{"function_name", "label"}], "helpers": [...]}
static func functions_page_content(sheet: EventSheetResource) -> Dictionary:
	if sheet == null or sheet.external_source_path.strip_edges().is_empty():
		return {}
	var published: Array[Dictionary] = []
	var helpers: Array[Dictionary] = []
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry as EventFunction
		if event_function.function_name.strip_edges().is_empty():
			continue
		var record: Dictionary = {
			"function_name": event_function.function_name.strip_edges(),
			"label": function_entry_label(event_function)
		}
		if event_function.expose_as_ace:
			published.append(record)
		else:
			helpers.append(record)
	if published.is_empty() and helpers.is_empty():
		return {}
	return {
		"title": "ƒ %s" % EventSheetL10n.translate("Functions"),
		"note": EventSheetL10n.translate("this script - %d") % (published.size() + helpers.size()),
		"published": published,
		"helpers": helpers,
		"helpers_header": "+ %s (%d)" % [EventSheetL10n.translate("Helpers"), helpers.size()]
	}


## One function's entry line: its display name, its kind in one word ("action" / "condition" /
## "expression" - void returns nothing, a bool answers a question, anything else hands a value
## back), then one chip per parameter as "<name> <type-word>". So a reader learns what the verb IS
## and what it takes without opening anything. An unpublished helper carries "not published" beside
## its kind: it is callable, but it is not part of any sheet's vocabulary.
static func function_entry_label(event_function: EventFunction) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(EventSheetBBCodeLite.strip(EventSheetVerbProperties.display_name_of(event_function)))
	var kind: String = EventSheetL10n.translate(ViewportRowBuilder.define_role_for(event_function))
	if not event_function.expose_as_ace:
		kind = "%s · %s" % [kind, EventSheetL10n.translate("not published")]
	parts.append(kind)
	for param: Variant in event_function.params:
		if param is ACEParam:
			parts.append("%s %s" % [
				ViewportRowBuilder.friendly_param_label(param as ACEParam),
				ViewportRowBuilder.friendly_type_word((param as ACEParam).type_name)
			])
	return "   ".join(parts)


## The script's own functions as pickable definitions: COPIES of the Core "Call Function" ACE with
## the target named up front, so choosing one inserts the ordinary call row - frozen ace id, frozen
## template - instead of anything new. The target rides in metadata; _commit_definition reads it
## back and pre-fills the parameters. Published verbs lead, helpers follow, matching the page.
static func function_call_definitions(sheet: EventSheetResource, registry: EventSheetACERegistry) -> Array[ACEDefinition]:
	var out: Array[ACEDefinition] = []
	if registry == null:
		return out
	# One rule for "is there a Functions page at all", shared with the page itself.
	if functions_page_content(sheet).is_empty():
		return out
	var base: ACEDefinition = registry.find_definition("Core", "CallFunction")
	if base == null:
		return out
	# Published first, then helpers, matching the page. Walked in ONE pass over the sheet per group
	# rather than by name lookup per entry, so a file with hundreds of functions stays linear while
	# the picker rebuilds this on every keystroke.
	for want_published: bool in [true, false]:
		for entry: Variant in sheet.functions:
			if not (entry is EventFunction):
				continue
			var event_function: EventFunction = entry as EventFunction
			var function_name: String = event_function.function_name.strip_edges()
			if function_name.is_empty() or event_function.expose_as_ace != want_published:
				continue
			# copy(), never duplicate(): an ACEDefinition's fields are plain vars, so duplicate()
			# would hand back a blank definition that still looks valid.
			var definition: ACEDefinition = base.copy()
			definition.display_name = "%s %s" % [
				EventSheetL10n.translate("Call"),
				EventSheetBBCodeLite.strip(EventSheetVerbProperties.display_name_of(event_function))
			]
			if not event_function.description.strip_edges().is_empty():
				definition.description = event_function.description.strip_edges()
			definition.metadata[FUNCTION_META_KEY] = function_name
			out.append(definition)
	return out


## Whether a search query should turn up one of the script's functions: part of the entry's own
## words ("Call Award Points"), part of the GDScript name a coder would type ("award_points"), or
## the same in-order subsequence the rest of the picker's search accepts. Static + pure so the
## searchable-ness of a function is pinned without a live picker window.
static func function_matches_query(definition: ACEDefinition, query: String) -> bool:
	if definition == null:
		return false
	var lowered: String = query.strip_edges().to_lower()
	if lowered.is_empty():
		return false
	if definition.display_name.to_lower().contains(lowered):
		return true
	if str(definition.metadata.get(FUNCTION_META_KEY, "")).to_lower().contains(lowered):
		return true
	return fuzzy_match(query, definition.display_name)


## The Functions section, built as the FIRST thing on the object page: what the open file itself
## can do comes before what the engine and the packs can do.
func _populate_function_cards(root: TreeItem) -> void:
	var content: Dictionary = functions_page_content(_open_sheet())
	if content.is_empty():
		return
	var header: TreeItem = _objects_tree.create_item(root)
	header.set_text(0, "%s   %s" % [str(content.get("title", "")), str(content.get("note", ""))])
	header.set_custom_color(0, GROUP_COLOR_CUSTOM)
	header.set_selectable(0, false)
	for entry: Variant in content.get("published", []):
		_add_function_item(header, entry as Dictionary, false)
	var helpers: Array = content.get("helpers", [])
	if helpers.is_empty():
		return
	# Folded, not hidden: the everyday reading is the published verbs, and the helpers are one
	# click away for the moment you do want to call one.
	var helpers_header: TreeItem = _objects_tree.create_item(header)
	helpers_header.set_text(0, str(content.get("helpers_header", "")))
	helpers_header.set_custom_color(0, GROUP_COLOR_NEUTRAL)
	helpers_header.set_selectable(0, false)
	helpers_header.collapsed = true
	for entry: Variant in helpers:
		_add_function_item(helpers_header, entry as Dictionary, true)


func _add_function_item(parent_item: TreeItem, entry: Dictionary, muted: bool) -> void:
	var function_name: String = str(entry.get("function_name", ""))
	var item: TreeItem = _objects_tree.create_item(parent_item)
	item.set_text(0, str(entry.get("label", "")))
	item.set_tooltip_text(0, EventSheetL10n.translate("Insert a call to %s in this script.") % function_name)
	item.set_metadata(0, "%s%s" % [FUNCTION_PREFIX, function_name])
	if muted:
		item.set_custom_color(0, GROUP_COLOR_NEUTRAL)
	# Headless has no editor theme, so this is null there and the entry simply carries no icon.
	var function_icon: Texture2D = editor_icon("MemberMethod")
	if function_icon != null:
		item.set_icon(0, function_icon)
		item.set_icon_max_width(0, 16)


func _populate_object_cards() -> void:
	if _objects_tree == null or _registry == null:
		return
	_objects_tree.clear()
	var root: TreeItem = _objects_tree.create_item()
	_populate_function_cards(root)
	var definitions: Array[ACEDefinition] = _registry.get_all_definitions()
	# System is one selectable row at the top (colored like a node-type header, it IS the
	# whole Core vocabulary); every other object sits under one section header.
	var objects_header: TreeItem = null
	for card: Dictionary in object_cards_for(definitions):
		var provider: String = str(card.get("provider"))
		var label: String = str(card.get("label"))
		var parent_item: TreeItem = root
		if provider != "Core":
			if objects_header == null:
				objects_header = _objects_tree.create_item(root)
				objects_header.set_text(0, "Objects & Behaviors")
				objects_header.set_custom_color(0, GROUP_COLOR_CUSTOM)
				objects_header.set_selectable(0, false)
			parent_item = objects_header
		var item: TreeItem = _objects_tree.create_item(parent_item)
		if provider == "Core":
			item.set_custom_color(0, GROUP_COLOR_NODE_TYPE)
		item.set_text(0, label)
		var tooltip: String = "Browse %s's conditions, actions, and triggers." % label
		# A pack can ship editor tooling as well as gameplay verbs, and until you installed it
		# nothing said so. The census reads the pack's own emitted scripts, so the card cannot claim a
		# dock the pack stopped hanging.
		var adds: String = EventSheetEditorToolCensus.summary(
			EventSheetEditorToolCensus.from_pack(EventSheets.addon_pack_directory(provider)))
		if not adds.is_empty():
			item.set_text(0, "%s  ·  %s" % [label, adds])
			tooltip += "\n%s" % adds
		item.set_tooltip_text(0, tooltip)
		item.set_metadata(0, provider)
		# Same icon discipline as the classic tree: the provider's own icon at 16px, never
		# scaled up; System gets the Node glyph from the editor theme.
		var item_icon: Texture2D = null
		for definition: ACEDefinition in definitions:
			if str(definition.provider_id) == provider and definition.icon.strip_edges().begins_with("res://"):
				item_icon = resolve_definition_icon(definition)
				if item_icon != null:
					break
		if item_icon == null:
			item_icon = editor_icon("Node" if provider == "Core" else "Script")
		if item_icon != null:
			item.set_icon(0, item_icon)
			item.set_icon_max_width(0, 16)
	_populate_project_cards(root)


## Your Project: the game's OWN classes and autoloads as object cards, so code you wrote
## yourself is one pick away with no annotations, no wizard, and no moving files. Picking a
## card scopes the tree exactly like a pack's card does - the members are reflected on
## demand (script-level, never instanced) by _project_definitions_for.
##
## Kept as its own section, never merged into the vocabulary categories: unannotated project
## members are a large, uncurated surface, and dumping them among the curated verbs is the
## "silent vocabulary pollution" the autoload provider path already refuses.
func _populate_project_cards(root: TreeItem) -> void:
	var entries: Array = EventSheetProjectScanner.list_project_classes()
	if entries.is_empty():
		return
	var header: TreeItem = _objects_tree.create_item(root)
	header.set_text(0, "Your Project")
	header.set_custom_color(0, GROUP_COLOR_CUSTOM)
	header.set_selectable(0, false)
	# Hidden classes are listed too, greyed and marked - hiding must not be a one-way door
	# with no path back, and a card the user cannot see is a card they cannot restore.
	var hidden_names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var entry_name: String = str(entry.get("name", ""))
		var singleton: String = str(entry.get("autoload", ""))
		if EventSheetVocabularyCatalog.is_class_excluded(entry_name):
			hidden_names.append(entry_name)
			continue
		var item: TreeItem = _objects_tree.create_item(header)
		item.set_text(0, entry_name if singleton.is_empty() else "%s (autoload)" % entry_name)
		item.set_tooltip_text(0, "Browse %s's methods, properties and signals - reflected from %s." % [
			entry_name, str(entry.get("path", ""))])
		# The metadata is the provider id the scoped tree filters on, which for a reflected
		# class IS the class name (see EventSheetClassDBSource).
		item.set_metadata(0, entry_name)
		var project_icon: Texture2D = editor_icon("Script")
		if project_icon != null:
			item.set_icon(0, project_icon)
			item.set_icon_max_width(0, 16)
	for hidden_name: String in hidden_names:
		var hidden_item: TreeItem = _objects_tree.create_item(header)
		hidden_item.set_text(0, "%s (hidden)" % hidden_name)
		hidden_item.set_custom_color(0, GROUP_COLOR_NEUTRAL)
		hidden_item.set_tooltip_text(0, "You hid %s. Select it to show it again." % hidden_name)
		# The metadata carries the restore intent; selecting it un-hides rather than scoping.
		hidden_item.set_metadata(0, "%s%s" % [UNHIDE_PREFIX, hidden_name])


## Identity-safe membership: two reflected contributions of the SAME verb can be different
## objects, because the catalog hands back a COPY for any verb it refined. Comparing by
## reference let a renamed verb appear beside its un-renamed twin (same provider::id, two
## rows), so membership is decided by identifier.
static func _contains_definition(definitions: Array, candidate: ACEDefinition) -> bool:
	if candidate == null:
		return true
	var identifier: String = candidate.get_identifier()
	for existing: ACEDefinition in definitions:
		if existing != null and existing.get_identifier() == identifier:
			return true
	return false


## The reflected verbs for a scoped project class, or [] when the scope is not one of the
## project's own classes. Autoloads emit `Singleton.member()`; everything else keeps the
## retargetable `{target.}member()` shape.
func _project_definitions_for(provider: String) -> Array[ACEDefinition]:
	if provider.strip_edges().is_empty():
		return []
	for entry: Dictionary in EventSheetProjectScanner.list_project_classes():
		if str(entry.get("name", "")) == provider:
			# The catalog refines presentation only (renames, categories, hidden entries);
			# ids and emitted calls come through untouched, which is what lets a project
			# delete the catalog without changing a single compiled sheet.
			return EventSheetVocabularyCatalog.apply(
				EventSheetClassDBSource.definitions_for_class(provider, str(entry.get("autoload", ""))))
	return []


## Single-click an object (the event-sheet first step): scope the classic tree to its verbs.
func _on_object_tree_selected() -> void:
	var selected: TreeItem = _objects_tree.get_selected()
	if selected == null or not (selected.get_metadata(0) is String):
		return
	# The way back from "Hide everything from X": selecting the greyed card restores it.
	var chosen: String = str(selected.get_metadata(0))
	if chosen.begins_with(UNHIDE_PREFIX):
		var restored: String = chosen.trim_prefix(UNHIDE_PREFIX)
		EventSheetVocabularyCatalog.set_class_excluded(restored, false)
		_populate_object_cards()
		if _info_label != null:
			_info_label.text = "%s is visible again." % restored
		return
	# A Functions entry is not an object to browse - it IS the row, so picking it adds the call.
	if chosen.begins_with(FUNCTION_PREFIX):
		_commit_function_call(chosen.trim_prefix(FUNCTION_PREFIX))
		return
	_object_filter_provider = str(selected.get_metadata(0))
	_objects_back.text = "◂ All objects · %s" % selected.get_text(0)
	_show_classic(true)
	_refresh_tree()
	_select_first_match()
	_search.grab_focus()


func _refresh_tree() -> void:
	if _tree == null or _registry == null:
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	# The whole sentence a reader typed - object, verb and value - filtered by its WORDS. A value
	# ("0.4", "\"boss\"") is not a word any row's name contains, so leaving it in the filter is what
	# made "boss fla 0.4" find nothing; it is what the row will be SET to, and it is picked up again
	# at commit. A query that is nothing but a value still searches for it literally, because then
	# it is the only thing the reader gave us to go on.
	var typed: String = _search.text.strip_edges()
	var query: String = EventSheetQuickAdd.words_query(typed)
	if query.is_empty():
		query = typed
	var mode: String = str(_context.get("mode", "new_event"))
	var signals_only: bool = bool(_context.get("signals_only", false))
	var is_event_mode: bool = mode in ["new_event", "new_condition_event", "new_sub_condition_event"]
	var filtering: bool = not query.is_empty()

	_blank_event_highlighted = false
	# ─────────────────────────────────────────────────────────────────────────────────────────────
	# A blank event is an event: it runs every tick. So the Add event dialog offers it FIRST, already
	# highlighted, and Enter makes it - the reader who just wants "do this every frame" never has to
	# hunt for a condition to satisfy the dialog. It only appears where a whole new TOP-LEVEL event is
	# being made (a sub-event's blank form is Add blank sub-event, and appending to an existing event
	# needs a real condition), and it survives a search that plainly means it.
	var blank_item: TreeItem = null
	if _blank_event_offered(mode, signals_only, query):
		blank_item = _tree.create_item(root)
		blank_item.set_text(0, EventSheetL10n.translate("(none - runs every tick)"))
		blank_item.set_metadata(0, {"blank_event": true})
		blank_item.set_tooltip_text(0, EventSheetL10n.translate(
			"An event with no condition of its own runs every tick."))

	var group_nodes: Dictionary = {}
	# Pre-declare node-type sections for event creation so they appear in a stable order.
	# While filtering, empty pre-declared sections are hidden (created on demand below).
	if is_event_mode and not signals_only and not filtering:
		for node_type: String in EVENT_PICKER_GROUPS:
			group_nodes[node_type] = _make_group_item(root, node_type, true)

	# ⭐ Favorites + ★ Recent now live in dedicated left panes (see _refresh_side_panes), not as
	# in-tree groups - so they stay visible while you browse categories, Create-Node style.

	var definitions: Array[ACEDefinition] = _registry.search(query)
	# Event-sheet vocabulary bridge: familiar event-sheet phrases also find their Godot equivalents.
	for synonym_query: String in _c3_synonym_queries(query):
		for extra_definition: ACEDefinition in _registry.search(synonym_query):
			if not definitions.has(extra_definition):
				definitions.append(extra_definition)
	# The other direction: a Godot user types the CALL they know. Every row whose template
	# writes that call answers, and so does the row the reading's idiom tables name for it, so
	# `queue_free` lands on Destroy and `is_on_floor` on Is on floor. The GDScript is written beside
	# the name below, which is what makes the two names visibly the same thing.
	_code_query = query if EventSheetCodeSearch.is_code_query(query) else ""
	if not _code_query.is_empty():
		for candidate: ACEDefinition in EventSheetCodeSearch.matching_definitions(
				_registry.get_all_definitions(), _code_query):
			if not definitions.has(candidate):
				definitions.append(candidate)
		var idiom_query: String = EventSheetCodeSearch.idiom_words(_code_query)
		if not idiom_query.is_empty():
			for idiom_definition: ACEDefinition in _registry.search(idiom_query):
				if not definitions.has(idiom_definition):
					definitions.append(idiom_definition)
	# "All of <host class>": the sheet's own class reflected on demand from ClassDB,
	# so ANY engine class is browsable vocabulary even without curated coverage
	# (and future Godot classes work the day they ship). Search filters by display
	# name like everything else; Simple Mode skips the deep end.
	if _reflect_class_provider.is_valid() and not signals_only:
		var simple: bool = _simple_mode_provider.is_valid() and bool(_simple_mode_provider.call())
		if not simple:
			var query_lower: String = query.to_lower()
			# The catalog applies HERE too. Without it every Rename / Hide offered on this
			# section was a silent no-op that still reported success, and this is the section
			# a user meets most (it is the sheet's own host class).
			for reflected: ACEDefinition in EventSheetVocabularyCatalog.apply(
					EventSheetClassDBSource.definitions_for_class(str(_reflect_class_provider.call()))):
				if filtering and not reflected.display_name.to_lower().contains(query_lower):
					continue
				if not _contains_definition(definitions, reflected):
					definitions.append(reflected)
	# Fuzzy fallback ("stt" -> Set Time Scale): subsequence matches on the display name
	# join AFTER exact + synonym hits, capped so noise never buries real matches.
	if filtering and query.length() >= 2:
		var fuzzy_added: int = 0
		for candidate: ACEDefinition in _registry.get_all_definitions():
			if fuzzy_added >= 12:
				break
			if definitions.has(candidate):
				continue
			if fuzzy_match(query, candidate.display_name):
				definitions.append(candidate)
				fuzzy_added += 1
	# The open file's OWN functions are vocabulary too: typing part of a function's name finds it
	# here, as the ordinary Call Function row aimed at that function. Search only - browsing them
	# is the object page's Functions section, and an unfiltered tree should not grow a second copy.
	if filtering:
		for function_definition: ACEDefinition in function_call_definitions(_open_sheet(), _registry):
			if function_matches_query(function_definition, query):
				definitions.append(function_definition)
	# And so are the LIGHTING NODES of the open scene: the same verbs, one copy per node,
	# with the node already chosen. Browsed as well as searched, because "which of my lights" is the
	# question a reader arrives with and a shelf they have to type to find is a shelf nobody meets.
	# And so are the DIALS of the shader materials that scene's nodes wear, on the same footing and
	# for the same reason: "which of my effects" is the question, and the dial names are the shader's
	# to give. A sheet whose scene wears no shader material grows no shelves and no general shelf.
	var dial_shelves: Array[ACEDefinition] = [] as Array[ACEDefinition]
	if not signals_only:
		dial_shelves = effect_dial_definitions(_open_sheet(), _registry)
		var dial_query: String = query.to_lower()
		for dial_definition: ACEDefinition in dial_shelves:
			# Either half of the entry answers a search: the dial ("dissolve") and the node it is
			# aimed at ("Boss"), because both are things a reader types looking for this row.
			if filtering and not (dial_definition.display_name.to_lower().contains(dial_query) \
					or str(dial_definition.metadata.get(SCENE_TARGET_META, "")) \
						.to_lower().contains(dial_query)):
				continue
			definitions.append(dial_definition)
	if not signals_only:
		var light_query: String = query.to_lower()
		for light_definition: ACEDefinition in scene_lighting_definitions(_open_sheet(), _registry):
			# Either half of the entry answers a search: the verb ("brightness") and the node it is
			# aimed at ("Torch"), because both are things a reader types looking for this row.
			if filtering and not (light_definition.display_name.to_lower().contains(light_query) \
					or str(light_definition.metadata.get(SCENE_TARGET_META, "")) \
						.to_lower().contains(light_query)):
				continue
			definitions.append(light_definition)
	# Behaviour-only host vocabulary: hide Host / Host Is Valid off a non-behaviour sheet (they read the
	# literal `host`, which only a behaviour sheet's prelude declares). Single chokepoint - `definitions`
	# is the assembled set that renders, so this covers search, synonyms, reflection, and fuzzy hits.
	var is_behavior_sheet: bool = _behavior_mode_provider.is_valid() and bool(_behavior_mode_provider.call())
	var host_filtered: Array[ACEDefinition] = []
	for host_candidate: ACEDefinition in definitions:
		if not host_ace_hidden(str(host_candidate.provider_id), str(host_candidate.id), is_behavior_sheet):
			host_filtered.append(host_candidate)
	definitions = host_filtered
	# The Editor object, on the same chokepoint: its rows only run inside the editor, so they are
	# offered on a @tool sheet and nowhere else. No provider wired = no gate, which is what keeps a
	# headless build and an embedder's picker showing exactly what they showed before.
	if _tool_mode_provider.is_valid():
		var is_tool_sheet: bool = bool(_tool_mode_provider.call())
		var tool_filtered: Array[ACEDefinition] = []
		for tool_candidate: ACEDefinition in definitions:
			if not editor_ace_hidden(str(tool_candidate.category), is_tool_sheet):
				tool_filtered.append(tool_candidate)
		definitions = tool_filtered
	# Object-first scope: a picked object card narrows the tree to that provider's verbs
	# (search still filters WITHIN the object, exactly the event-sheet second step).
	if not _object_filter_provider.is_empty():
		# A "Your Project" card scopes to a class the registry has no definitions for - its
		# verbs are reflected on demand here, so they exist to be scoped to. Reflection is
		# cached per class, so re-entering the same object costs a dictionary lookup.
		for project_definition: ACEDefinition in _project_definitions_for(_object_filter_provider):
			if not _contains_definition(definitions, project_definition):
				definitions.append(project_definition)
		var provider_scoped: Array[ACEDefinition] = []
		for scoped_candidate: ACEDefinition in definitions:
			if str(scoped_candidate.provider_id) == _object_filter_provider:
				provider_scoped.append(scoped_candidate)
		definitions = provider_scoped
	# Reactivity steering: surface a polling condition's reactive twin beside it (off the shared
	# ACEDescriptor.REACTS_TO map), so "react instead?" is one keystroke away; _best_match_item then
	# pre-selects it, and the mode filter below drops the trigger where it is not a valid choice.
	if filtering:
		var reactive_twins: Array[ACEDefinition] = []
		for matched: ACEDefinition in definitions:
			var twin_id: String = _reactive_twin_id(matched)
			if twin_id.is_empty():
				continue
			var twin_def: ACEDefinition = _registry.find_definition(matched.provider_id, twin_id)
			if twin_def != null and not definitions.has(twin_def) and not reactive_twins.has(twin_def):
				reactive_twins.append(twin_def)
		definitions.append_array(reactive_twins)
	# Featured ACEs (the everyday verbs) float to the top of their group + render bold below - the "highlight".
	if not definitions.is_empty():
		var __featured: Array[ACEDefinition] = []
		var __rest: Array[ACEDefinition] = []
		for __d: ACEDefinition in definitions:
			if _is_featured(__d):
				__featured.append(__d)
			else:
				__rest.append(__d)
		definitions = __featured
		definitions.append_array(__rest)
	definitions = ordered_variable_verbs(definitions)
	for definition: ACEDefinition in definitions:
		if not _is_allowed_for_mode(definition, mode, signals_only):
			continue
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		# ────────────────────────────────────────────────────────────────────────────────────────
		# The 3D page. Scoping a row to a node type is what decides which objects may drop it, and
		# until now it also decided where it was FILED - so every 3D verb sat in one flat "Node3D"
		# list while the 2D ones were sorted into named sections. A row filed on the 3D page keeps
		# that page, which is the only way a node-scoped row can be sorted the way an unscoped one
		# is. Held to that one page on purpose: it is the only category a shipped row spells this
		# way, so no existing row's group can move under it.
		var paged: bool = _category_of(definition).begins_with(SPATIAL_PAGE_PREFIX)
		var is_node_type_group: bool = not node_type.is_empty() and not paged
		var group_key: String = node_type if is_node_type_group else _category_of(definition)
		# Every comparison but the lead one files under Variables ▸ All comparisons, wherever
		# its descriptor's own category puts it. Outranks the node-type filing for the same reason
		# the page prefix does: what a row IS beats where it happens to have been filed.
		var comparison_key: String = comparison_group_key(definition)
		if not comparison_key.is_empty():
			group_key = comparison_key
			is_node_type_group = false
		# The Multiplayer triggers sort onto three named shelves inside their own section, for
		# the same reason the comparisons do: "what can happen in a networked game" is a list nobody
		# reads flat. Outranks the node-type filing so a spawner's own event is still found under
		# Multiplayer, where the reader went looking for it.
		var multiplayer_key: String = multiplayer_group_key(definition)
		if not multiplayer_key.is_empty():
			group_key = multiplayer_key
			is_node_type_group = false
		# A row the picker built for one node of the open scene is filed under that node,
		# not under the class it is: the reader picked "Torch", not "PointLight2D".
		var light_key: String = scene_lighting_group_key(definition)
		if not light_key.is_empty():
			group_key = light_key
			is_node_type_group = false
		# The same filing for the effect dials, and for the free-string rows beside them: a reader who
		# picked "Boss" and "dissolve" picked a node and a dial, not the class CanvasItem.
		var effect_key: String = effect_group_key(definition, not dial_shelves.is_empty())
		if not effect_key.is_empty():
			group_key = effect_key
			is_node_type_group = false
		var group_item: TreeItem = _resolve_group_item(root, group_nodes, group_key, is_node_type_group)
		var item: TreeItem = _tree.create_item(group_item)
		var featured: bool = _is_featured(definition)
		# Featured rows lead with a star so the highlight is legible even where bold barely
		# differs from regular (small font sizes / some system fonts).
		item.set_text(0, ("★ " + _item_label(definition)) if featured else _item_label(definition))
		var item_icon: Texture2D = resolve_definition_icon(definition)
		if item_icon != null:
			item.set_icon(0, item_icon)
			item.set_icon_max_width(0, 16)
		# A pack class the editor theme can't resolve (custom classes aren't EditorIcons) still
		# gets a section icon: promote the first row's own @ace_icon texture onto its header.
		# Guarded to explicit res:// icons so a builtin row's kind dot never claims a header.
		if group_item.get_icon(0) == null and definition.icon.strip_edges().begins_with("res://") and item_icon != null:
			group_item.set_icon(0, item_icon)
			group_item.set_icon_max_width(0, 16)
		item.set_tooltip_text(0, _item_tooltip(definition))
		item.set_metadata(0, definition)
		_add_help_button(item, definition)
		if featured:
			var __bold: Font = _bold_font()
			if __bold != null:
				item.set_custom_font(0, __bold)

	_add_alias_rows(root, group_nodes, mode, signals_only, query)

	# No-match guidance: a blank tree leaves a newcomer stuck wondering if the picker is broken.
	# Nudge the vocabulary bridge (plain phrases find Godot equivalents) instead of silence.
	if filtering and root.get_child_count() == 0:
		var empty_item: TreeItem = _tree.create_item(root)
		empty_item.set_text(0, "No matches for \"%s\" - try a plainer word like \"move\", \"spawn\", or \"hide\"." % query)
		empty_item.set_selectable(0, false)
		empty_item.set_custom_color(0, GROUP_COLOR_NEUTRAL)

	# First-open calm: with no query the tree reads as a table of contents - every section starts
	# collapsed (the event-sheet reflex: pick the object first, then browse its verbs) instead of
	# 250+ rows under dozens of expanded headers. Searching rebuilds the tree expanded so matches
	# are immediately visible, and preselect() re-expands the ancestors of a targeted entry.
	if not filtering:
		var section: TreeItem = root.get_first_child()
		while section != null:
			section.collapsed = true
			section = section.get_next()

	# With nothing typed, the blank event is what Enter makes: it is the first entry and it
	# starts selected, so "an event that runs every tick" costs one key.
	if blank_item != null and not filtering:
		blank_item.select(0)
		_on_blank_event_highlighted()


## Whether the Add event dialog offers its blank first entry. Only for a whole new top-level
## event, never for signals-only or the append modes, and while searching only when the query plainly
## reaches for it.
func _blank_event_offered(mode: String, signals_only: bool, query: String) -> bool:
	if signals_only or mode != "new_event":
		return false
	var lowered: String = query.strip_edges().to_lower()
	if lowered.is_empty():
		return true
	for word: String in ["none", "blank", "every tick", "tick", "every"]:
		if word.begins_with(lowered) or word.contains(lowered):
			return true
	return false


## The blank entry is highlighted: the description panel says what it makes, and Add commits it.
func _on_blank_event_highlighted() -> void:
	_selected_definition = null
	_blank_event_highlighted = true
	_update_guide_button(null)
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(false)
	if _add_button != null:
		_add_button.disabled = false
	if _info_label != null:
		_info_label.text = "[b]%s[/b]\n%s" % [
			EventSheetL10n.translate("(none - runs every tick)"),
			EventSheetL10n.translate("An event with no condition of its own runs every tick. Add its actions with A, or add a condition later to narrow it down.")]


## Commits the blank first entry: a new event with no condition, where the dialog was opened.
func _commit_blank_event() -> void:
	close()
	blank_event_selected.emit(_context.duplicate(true))


func _make_group_item(root: TreeItem, group_key: String, is_node_type: bool) -> TreeItem:
	var group_item: TreeItem = _tree.create_item(root)
	group_item.set_text(0, group_key)
	# Every section shows its object/module icon next to its name (event-sheet users expect the
	# icon everywhere): node-type sections use the class's editor icon, vocabulary sections resolve
	# through category_icon_name, which DERIVES one from the category's name or its verbs' host
	# rather than requiring the category to be listed anywhere. A pack class the editor theme
	# doesn't know gets its icon later, from its first definition's own icon (see _rebuild_tree).
	var header_icon: Texture2D = editor_icon(group_key) if is_node_type else category_header_icon(group_key)
	if header_icon != null:
		group_item.set_icon(0, header_icon)
		group_item.set_icon_max_width(0, 16)
	group_item.set_custom_color(0, _group_color_for(group_key, is_node_type))
	_mark_section_header(group_item, group_key)
	return group_item


## The editor-theme icon for a builtin category header ("Math & Random" -> the
## RandomNumberGenerator icon). Null outside a live editor or for unmapped categories
## (text-only header, exactly the pre-icon look). `host_hint` is the category's own host class
## when the caller knows it - a pack's definition carries one, and it lets a pack category
## resolve an icon without ever being listed anywhere.
static func category_header_icon(group_key: String, host_hint: String = "") -> Texture2D:
	var icon_name: String = category_icon_name(group_key, host_hint)
	return null if icon_name.is_empty() else editor_icon(icon_name)


## Resolves a category to its EditorIcons name, DERIVING one wherever it can so that adding a
## category to the vocabulary is not also a chore in this file. In order:
##   1. an explicit CATEGORY_EDITOR_ICONS entry (a human choice, and the override),
##   2. the category NAME read as a class, case-insensitively ("Raycast 2D" -> RayCast2D,
##      "Tilemap" -> TileMap) - the name a category already has is usually the icon it wants,
##   3. for a "Parent: Sub" key, the PARENT's explicit entry: a family whose icon someone chose
##      deliberately keeps it across its sub-sections, rather than each sub drifting to its own
##      derived host ("Nodes: Picking" stays on the Nodes icon, not Node2D),
##   4. the host class its verbs actually operate on: the caller's `host_hint`, else the most
##      specific host shared by the builtin ACEs in that category ("UI" -> Control),
##   5. a "Parent: Sub" key inheriting whatever its parent DERIVES,
##   6. "" - a text-only header, exactly the pre-icon look.
## Pure + static so the mapping stays unit-testable without a display server.
static func category_icon_name(group_key: String, host_hint: String = "") -> String:
	var explicit: String = str(CATEGORY_EDITOR_ICONS.get(group_key, ""))
	if not explicit.is_empty():
		return explicit
	var from_name: String = _class_named(group_key)
	if not from_name.is_empty():
		return from_name
	var parts: PackedStringArray = split_subcategory(group_key)
	if not parts.is_empty():
		var parent_explicit: String = str(CATEGORY_EDITOR_ICONS.get(parts[0], ""))
		if not parent_explicit.is_empty():
			return parent_explicit
	var from_hint: String = _class_named(host_hint)
	if not from_hint.is_empty():
		return from_hint
	var derived: String = str(_category_host_classes().get(group_key, ""))
	if not derived.is_empty():
		return derived
	if not parts.is_empty():
		return category_icon_name(parts[0], host_hint)
	return ""


## The engine class a label names, ignoring case and spacing, or "" when it names none. Category
## labels are written for humans ("Raycast 2D", "Tilemap") while classes are PascalCase with their
## own capitalisation quirks (RayCast2D, TileMap), so an exact match would miss almost every one.
static func _class_named(label: String) -> String:
	var key: String = label.replace(" ", "").replace("&", "").replace("-", "").to_lower()
	if key.is_empty():
		return ""
	return str(_class_names_by_lowercase().get(key, ""))


## lowercase class name -> its exact ClassDB spelling. Built once: the class list is ~1000 entries
## and this is consulted for every header drawn.
static var _class_lookup: Dictionary = {}


static func _class_names_by_lowercase() -> Dictionary:
	if not _class_lookup.is_empty():
		return _class_lookup
	for class_id: String in ClassDB.get_class_list():
		_class_lookup[class_id.to_lower()] = class_id
	return _class_lookup


## category -> the most specific host class its builtin verbs share, or "" when they are
## host-agnostic (a "Math & Random" verb runs anywhere, so nothing is derivable and the explicit
## table is the only answer). "Most specific" means the deepest in the inheritance chain that
## still covers every hosted verb, so "Raycast 2D" lands on RayCast2D rather than Node2D even
## though a few of its world-query verbs are plain Node2D.
static var _category_hosts: Dictionary = {}


## The Godot class a vocabulary entry is scoped to, whichever shape the entry is.
##
## The builtin list holds BOTH kinds and always has: an ACEDescriptor keeps the host in `node_type`,
## while an ACEDefinition - the shape a provider script and EventSheets.simple_ace produce - has no
## such property and keeps it in `metadata`. Reading `.node_type` unconditionally therefore threw
## once per definition, which is invisible headless (the definitions only join in a live editor) and
## filled the Output dock the moment anyone opened a sheet.
static func host_class_of(entry: Variant) -> String:
	if entry is ACEDescriptor:
		return str((entry as ACEDescriptor).node_type).strip_edges()
	if entry is ACEDefinition:
		return str(((entry as ACEDefinition).metadata as Dictionary).get("node_type", "")).strip_edges()
	return ""


static func _category_host_classes() -> Dictionary:
	if not _category_hosts.is_empty():
		return _category_hosts
	var counts: Dictionary = {}
	for entry: Variant in EventForgeBuiltinACEs.get_descriptors():
		var host: String = host_class_of(entry)
		if host.is_empty() or not ClassDB.class_exists(host):
			continue
		var category: String = str(entry.get("category"))
		if not counts.has(category):
			counts[category] = {}
		var per_category: Dictionary = counts[category]
		per_category[host] = int(per_category.get(host, 0)) + 1
	for category: String in counts:
		_category_hosts[category] = _dominant_host(counts[category])
	return _category_hosts


## The host that best represents a category: the one used most, breaking ties toward the more
## derived class (RayCast2D over Node2D) so the icon shows the specific thing the section is
## about rather than the generic base every node shares.
static func _dominant_host(host_counts: Dictionary) -> String:
	var best: String = ""
	var best_count: int = 0
	for host: String in host_counts:
		var count: int = int(host_counts[host])
		if count > best_count or (count == best_count and ClassDB.is_parent_class(best, host)):
			best = host
			best_count = count
	return best


## Resolves (creating as needed) the tree item a row hangs under. Categories using the
## "Parent: Sub" separator nest one level - the parent folder is shared with any flat ACEs
## in the same category, and each distinct sub gets its own folder. Node-type sections and
## separator-less categories stay flat, exactly as before.
func _resolve_group_item(root: TreeItem, group_nodes: Dictionary, group_key: String, is_node_type: bool) -> TreeItem:
	if group_nodes.has(group_key):
		return group_nodes[group_key]
	var parts: PackedStringArray = PackedStringArray() if is_node_type else split_subcategory(group_key)
	if parts.is_empty():
		var flat_item: TreeItem = _make_group_item(root, group_key, is_node_type)
		group_nodes[group_key] = flat_item
		return flat_item
	var parent_key: String = parts[0]
	var child_label: String = parts[1]
	var parent_item: TreeItem
	if group_nodes.has(parent_key):
		parent_item = group_nodes[parent_key]
	else:
		parent_item = _make_group_item(root, parent_key, false)
		group_nodes[parent_key] = parent_item
	var sub_item: TreeItem = _make_sub_group_item(parent_item, child_label, group_key)
	group_nodes[group_key] = sub_item
	return sub_item


## A nested sub-category folder ("Array" inside "Variables"): same folder styling as a top-level
## group, parented under its category instead of the tree root. The full "Parent: Sub" key is kept
## as the section name so its description looks up unambiguously.
func _make_sub_group_item(parent_item: TreeItem, child_label: String, full_key: String) -> TreeItem:
	var sub_item: TreeItem = _tree.create_item(parent_item)
	sub_item.set_text(0, child_label)
	var sub_icon: Texture2D = category_header_icon(full_key)
	if sub_icon != null:
		sub_item.set_icon(0, sub_icon)
		sub_item.set_icon_max_width(0, 16)
	sub_item.set_custom_color(0, _group_color_for(child_label, false))
	_mark_section_header(sub_item, full_key)
	return sub_item


## Makes a group / sub-group header selectable and tags it with its section name, so selecting the
## header shows a description instead of an ACE. The metadata is a marker Dictionary, never an
## ACEDefinition, so the Add button stays disabled and confirming a header does nothing (see
## _commit_definition, which no-ops on null). Any registered blurb also becomes the hover tooltip.
func _mark_section_header(item: TreeItem, section_name: String) -> void:
	item.set_selectable(0, true)
	item.set_metadata(0, {"section": section_name})
	var blurb: String = EventSheetSectionInfo.description_for(section_name)
	if not blurb.is_empty():
		item.set_tooltip_text(0, blurb)


## Splits a "Parent: Sub" category into [parent, child] (both stripped). Returns an empty
## array when there is no sub-category separator, so the category renders as a flat group.
## Pure + static so the grouping can be unit-tested without a display server.
static func split_subcategory(group_key: String) -> PackedStringArray:
	var index: int = group_key.find(SUBCATEGORY_SEPARATOR)
	if index == -1:
		return PackedStringArray()
	var parent_name: String = group_key.substr(0, index).strip_edges()
	var child_name: String = group_key.substr(index + SUBCATEGORY_SEPARATOR.length()).strip_edges()
	if parent_name.is_empty() or child_name.is_empty():
		return PackedStringArray()
	return PackedStringArray([parent_name, child_name])


## Resolves an ACE's icon: an explicit `res://` texture from the addon's @ace_icon annotation,
## else a small dot in the ACE type's role colour. The dot replaced two older fallbacks - the
## row's node-type class icon (redundant: the section header already shows it) and Godot's
## member glyphs (MemberSignal/MemberMethod/…, insider vocabulary a newcomer can't read).
## Colour is the sheet's own visual language: the dot reuses the exact lane colours the rows
## paint with, so "teal = a yes/no test" transfers from the picker to the sheet and back.
## Static + shared so row rendering can reuse it later.
static func resolve_definition_icon(definition: ACEDefinition) -> Texture2D:
	if definition == null:
		return null
	var icon_hint: String = definition.icon.strip_edges()
	if icon_hint.begins_with("res://") and ResourceLoader.exists(icon_hint):
		var loaded: Resource = load(icon_hint)
		if loaded is Texture2D:
			return loaded
	return kind_dot(definition.ace_type)


static var _kind_dot_cache: Dictionary = {}


## A small filled dot in the given ACE type's role colour (trigger purple, condition teal, action
## amber, expression magenta - EventSheetPalette's lane colours). Image-built and cached per type,
## so it renders identically in the editor and headless.
static func kind_dot(ace_type: int) -> Texture2D:
	if _kind_dot_cache.has(ace_type):
		return _kind_dot_cache[ace_type]
	var color: Color = EventSheetPalette.COLOR_ACTION
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			color = EventSheetPalette.COLOR_TRIGGER
		ACEDefinition.ACEType.CONDITION:
			color = EventSheetPalette.COLOR_CONDITION
		ACEDefinition.ACEType.EXPRESSION:
			color = EventSheetPalette.COLOR_EXPRESSION
	var dot_size: int = 12
	var image: Image = Image.create(dot_size, dot_size, false, Image.FORMAT_RGBA8)
	var center: float = (dot_size - 1) * 0.5
	var radius: float = 4.5
	for y in range(dot_size):
		for x in range(dot_size):
			# 1px soft edge so the dot reads round at UI scale, not as a jagged square of pixels.
			var alpha: float = clampf(radius + 0.5 - Vector2(x - center, y - center).length(), 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_kind_dot_cache[ace_type] = texture
	return texture


## Fetches a named editor-theme icon ("EditorIcons" - class icons and member glyphs).
## Null outside the editor or when the name is unknown, so callers degrade gracefully.
static func editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_icon(icon_name, "EditorIcons"):
		return null
	return theme.get_icon(icon_name, "EditorIcons")


func _category_of(definition: ACEDefinition) -> String:
	var category: String = definition.category.strip_edges()
	return category if not category.is_empty() else "General"


## The Godot call the current search was typed as, "" for an ordinary word search. Held for
## one tree rebuild so the matched rows can write that call beside their names.
var _code_query: String = ""


## The Variables verbs, put back into the order a reader looks for them: set it, change it by an
## amount, the boolean pair, then the two questions. Everything else keeps the order it arrived in,
## and the section as a whole keeps the position its first member had - so this reorders WITHIN the
## Variables group and moves nothing else. Static + pure, so the order is pinned without a dialog.
static func ordered_variable_verbs(definitions: Array[ACEDefinition]) -> Array[ACEDefinition]:
	var variables: Array[ACEDefinition] = []
	for definition: ACEDefinition in definitions:
		if definition.category == VARIABLES_CATEGORY \
				and EventSheetVariableOwners.VARIABLE_VERB_ORDER.has(str(definition.id)):
			variables.append(definition)
	if variables.size() < 2:
		return definitions
	variables.sort_custom(func(left: ACEDefinition, right: ACEDefinition) -> bool:
		return EventSheetVariableOwners.verb_rank(str(left.id)) \
			< EventSheetVariableOwners.verb_rank(str(right.id)))
	var ordered: Array[ACEDefinition] = []
	var next_variable: int = 0
	for definition: ACEDefinition in definitions:
		if definition.category == VARIABLES_CATEGORY \
				and EventSheetVariableOwners.VARIABLE_VERB_ORDER.has(str(definition.id)):
			ordered.append(variables[next_variable])
			next_variable += 1
		else:
			ordered.append(definition)
	return ordered


func _item_label(definition: ACEDefinition) -> String:
	# Display names route through the plugin l10n layer (a pass-through in English), so a pack
	# that ships a translation CSV gets localised picker rows for free. Ids never translate.
	var display_name: String = EventSheetL10n.translate(definition.display_name)
	# The GDScript beside the name, on the rows a code search found: the proof that the sheet's
	# word and the call the reader typed are the same row. Never translated - it is code.
	if not _code_query.is_empty():
		var hint: String = EventSheetCodeSearch.gdscript_hint(definition, _code_query)
		if not hint.is_empty():
			display_name = "%s  ·  %s" % [display_name, hint]
	# A variable verb says which variables it can take, so "Add to" with no numbers in scope
	# reads as empty before it is clicked rather than after.
	var takes: String = variable_verb_note(_variables_in_scope(), definition)
	if not takes.is_empty():
		display_name = "%s  ·  %s" % [display_name, takes]
	if definition.provider_id.is_empty() or definition.provider_id == "Core":
		return display_name
	# Title-case the pack suffix for display ("weapon_kit" -> "Weapon Kit"): raw snake_case ids
	# read as internals, not as the addon's name. Display-only - the id itself never changes.
	return "%s  ·  %s" % [display_name, definition.provider_id.capitalize()]


## The id every "?" on a row carries. One id, because there is one question a "?" asks.
const HELP_BUTTON_ID := 1


## The small "?" at the end of an entry - "Help for this action" - which opens the verb's entry in
## the Manual without losing the reader's place in the picker.
##
## Silent when this editor build carries no help icon (and headless, where there is no theme at
## all): Tree.add_button needs a texture, and a row with an invisible button is a click target
## nobody can see. The hover mini-page below still answers, and so does F1.
func _add_help_button(item: TreeItem, definition: ACEDefinition) -> void:
	var icon: Texture2D = editor_icon_named("Help")
	if icon == null or definition == null:
		return
	item.add_button(0, icon, HELP_BUTTON_ID, false,
		EventSheetL10n.translate("Help for this %s") % _ace_type_label(definition.ace_type).to_lower())


func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	if id != HELP_BUTTON_ID or mouse_button_index != MOUSE_BUTTON_LEFT or item == null:
		return
	var definition: ACEDefinition = item.get_metadata(0) as ACEDefinition
	if definition != null:
		help_requested.emit(definition)


## An editor theme icon by name, or null outside the editor and for a name this build lacks.
static func editor_icon_named(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_icon(icon_name, "EditorIcons"):
		return null
	return theme.get_icon(icon_name, "EditorIcons")


## The MINI-PAGE a row shows on hover: what it is and what it does, the line it ships as, and -
## when this sheet already uses it - how often. Three facts, which is what a reader hovering a
## row is deciding between two entries with; the whole entry is one "?" away.
static func mini_page(definition: ACEDefinition, used: int) -> String:
	if definition == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var ships_as: String = EventSheetDocExplain.ships_as(definition)
	if not ships_as.is_empty():
		lines.append("→ %s" % ships_as)
	if used > 0:
		lines.append(EventSheetL10n.translate("Used %d× in this sheet") % used)
	return "\n".join(lines)


func _item_tooltip(definition: ACEDefinition) -> String:
	var body: String = EventSheetL10n.translate(definition.description if not definition.description.is_empty() else definition.display_name)
	var tip: String = "[%s]  %s" % [_ace_type_label(definition.ace_type), body]
	# Deprecated entries are filtered out of the picker, but a still-surfaced one (e.g. via search/recents)
	# carries its deprecation note so the user is steered to the replacement.
	var note: String = str(definition.metadata.get("deprecation_note", ""))
	if not note.is_empty():
		tip += "\n" + note
	# Provenance: a verb derived from the user's own script says so, and says it can be
	# changed - otherwise an inferred name reads as if the plugin decided it and there is
	# no visible way to disagree.
	var provenance: String = EventSheetVocabularyCatalog.provenance_note(definition)
	if not provenance.is_empty():
		tip += "\n" + provenance
	# The mini-page: the line it ships as, and how much the open sheet already uses it. It rides on
	# the tooltip rather than on a popup of its own because a hover that opens a window is a hover
	# that gets in the way of the arrow keys.
	var mini: String = mini_page(definition,
		EventSheetDocUsage.count(_open_sheet(), definition.provider_id, definition.id))
	if not mini.is_empty():
		tip += "\n" + mini
	return tip


func _ace_type_label(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			return "Trigger"
		ACEDefinition.ACEType.CONDITION:
			return "Condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expression"
		_:
			return "Action"


func _group_color_for(_group_key: String, _is_node_type: bool) -> Color:
	# Muted, uniform category headers (Create-New-Node style): the node-type distinction is carried by
	# each section's class icon, so a quiet divider colour reads cleaner than the old bright per-kind
	# amber/teal/blue/purple. Theme-driven in the editor, with a neutral fallback when headless.
	return _muted_header_color()


## The editor's muted "disabled font" colour for quiet category dividers / de-emphasized codegen;
## GROUP_COLOR_NEUTRAL when there is no editor theme (headless tests, non-editor runtime).
func _muted_header_color() -> Color:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface != null and editor_interface.has_method("get_editor_theme"):
			var theme: Theme = editor_interface.get_editor_theme()
			if theme != null and theme.has_color("font_disabled_color", "Editor"):
				return theme.get_color("font_disabled_color", "Editor")
	return GROUP_COLOR_NEUTRAL

## The everyday "featured" verbs (event-sheet-style highlight): rendered bold and floated to the top of their
## group so the common picks stand out. THE curated Core list lives here in one glance
## (keys are "provider_id/ace_id"; featured_aces_test typo-gates every key against the
## live registry). It leads with INTENTIONS - wait, spawn, destroy, play, move - not
## statements. Addons feature their own hero verbs via `.featured()` (module style) or
## `## @ace_featured` (annotation style), which arrive through definition metadata.
const FEATURED := {
	"Core/OnReady": true, "Core/OnProcess": true, "Core/OnPhysicsProcess": true,
	"Core/IsActionPressed": true, "Core/CompareVar": true, "Core/CompareValues": true,
	"Core/SetVar": true, "Core/AddVar": true, "Core/PrintLog": true,
	"Core/CallFunction": true, "Core/SpawnSceneFull": true,
	"Core/Wait": true, "Core/EveryXSeconds": true, "Core/PlaySound": true,
	"Core/PlayAnimationInObject": true, "Core/QueueFree": true,
	"Core/EmitSignal": true, "Core/MoveTowardValue": true,
}


func _is_featured(definition: ACEDefinition) -> bool:
	if definition == null:
		return false
	if bool(definition.metadata.get("featured", false)):
		return true
	return FEATURED.has("%s/%s" % [definition.provider_id, definition.id])


## The bold font for featured rows: the editor theme's when hosted, else a synthesized
## embolden of the fallback font - so the highlight reads everywhere, not only inside
## a themed editor.
func _bold_font() -> Font:
	if _tree != null and _tree.has_theme_font("bold", "EditorFonts"):
		return _tree.get_theme_font("bold", "EditorFonts")
	var variation: FontVariation = FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_embolden = 0.7
	return variation


func _is_allowed_for_mode(definition: ACEDefinition, mode: String, signals_only: bool) -> bool:
	if definition == null:
		return false
	# Deprecated ACEs are hidden from the picker so they can't be added to NEW work - but they still
	# compile in sheets that already use them (the compatibility covenant; see ACEDescriptor.deprecated).
	if bool(definition.metadata.get("deprecated", false)):
		return false
	# A row the project names the choices for is offered as the COPIES built from the open scene -
	# one per node per dial, with both already answered. The bare row is not browsable, because all
	# it could do is ask for the very name it exists to stop somebody typing.
	if bool(definition.metadata.get("project_scoped", false)) \
			and str(definition.metadata.get(SCENE_TARGET_META, "")).is_empty():
		return false
	# Simple Mode hides the advanced / code-drop ACEs (Run GDScript, Evaluate, Breakpoint, …).
	if _simple_mode_provider.is_valid() and bool(_simple_mode_provider.call()) and _SIMPLE_MODE_DENYLIST.has(definition.provider_id + "::" + definition.id):
		return false
	if signals_only:
		# Use source_kind metadata for precise signal detection (set by the generator).
		# Fall back to category string only when metadata is absent.
		var source_kind: String = str(definition.metadata.get("source_kind", ""))
		var is_signal: bool = source_kind == "signal" or (source_kind.is_empty() and definition.category.to_lower().contains("signal"))
		return definition.ace_type == ACEDefinition.ACEType.TRIGGER and is_signal
	match mode:
		"new_condition_event":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"new_sub_condition_event":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"append_condition":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"append_action":
			return definition.ace_type == ACEDefinition.ACEType.ACTION
		"replace_condition":
			return definition.ace_type == ACEDefinition.ACEType.CONDITION
		"replace_trigger":
			return definition.ace_type == ACEDefinition.ACEType.TRIGGER
		"replace_action":
			return definition.ace_type == ACEDefinition.ACEType.ACTION
		_:
			return definition.ace_type in [ACEDefinition.ACEType.TRIGGER, ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.ACTION]


## Event-sheet-style bottom info pane: selecting an entry shows its description AND the exact
## GDScript it will generate - the picker doubles as a teaching surface.
func _on_item_selected_for_info() -> void:
	var selected: TreeItem = _tree.get_selected()
	# A section header carries a {"section": name} marker (not an ACE): show the group's description.
	if selected != null:
		var meta: Variant = selected.get_metadata(0)
		if meta is Dictionary and (meta as Dictionary).has("blank_event"):
			_on_blank_event_highlighted()
			return
		if meta is Dictionary and (meta as Dictionary).has("section"):
			_show_section_info(selected, str((meta as Dictionary)["section"]))
			return
	_blank_event_highlighted = false
	var definition: ACEDefinition = selected.get_metadata(0) as ACEDefinition if selected != null else null
	# Picking in the main tree clears the side-pane highlight so there is one logical selection.
	if definition != null:
		if _favorites_list != null:
			_favorites_list.deselect_all()
		if _recent_list != null:
			_recent_list.deselect_all()
	_on_definition_selected(definition)


## Right-click pins/unpins the entry under the cursor as a ⭐ Favorite.
## Keyboard bridge out of the search box: Down hands focus to the result tree (its native arrow
## navigation then takes over from the pre-selected first match), Escape closes the picker. Without
## this the caret is trapped in the search field and only the mouse can reach the 2nd+ result.
func _on_search_gui_input(input_event: InputEvent) -> void:
	if not (input_event is InputEventKey):
		return
	var key_event: InputEventKey = input_event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_DOWN:
		if _tree != null and _tree.get_root() != null:
			# Ensure a row is selected (the first match) before handing over, so the tree gains
			# focus on a real item and subsequent arrows navigate predictably.
			if _tree.get_selected() == null:
				_select_first_match()
			_tree.grab_focus()
			_search.accept_event()
	elif key_event.keycode == KEY_ESCAPE:
		close()
		_search.accept_event()


func _on_tree_gui_input(input_event: InputEvent) -> void:
	# Escape closes the picker from the tree too (parity with the search box), so a keyboard user
	# browsing results never has to reach for the mouse or the Cancel button.
	if input_event is InputEventKey:
		var key_event: InputEventKey = input_event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			close()
			_tree.accept_event()
		return
	if not (input_event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = input_event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var clicked: TreeItem = _tree.get_item_at_position(mouse_event.position)
	var clicked_meta: Variant = clicked.get_metadata(0) if clicked != null else null
	if not (clicked_meta is ACEDefinition):
		return
	_open_tree_context_menu(clicked_meta as ACEDefinition)


## Right-click menu on a result row: the favorite toggle plus copy-ready authoring
## stubs, so an author can learn either provider dialect from any existing ACE
## (paste the stub into a provider script and edit).
func _open_tree_context_menu(definition: ACEDefinition) -> void:
	if _tree_context_menu == null:
		_tree_context_menu = PopupMenu.new()
		_window.add_child(_tree_context_menu)
		_tree_context_menu.id_pressed.connect(_on_tree_context_menu_pressed)
	_tree_context_definition = definition
	_tree_context_menu.clear()
	_tree_context_menu.add_item("Pin / Unpin Favorite", 0)
	# Refinement for DERIVED verbs only: an authored verb's identity lives in its script, and
	# the catalog deliberately never overrules source (it would be an invisible second truth).
	if not EventSheetVocabularyCatalog.provenance_of(definition).is_empty():
		_tree_context_menu.add_separator()
		_tree_context_menu.add_item("Rename this entry…", 3)
		_tree_context_menu.add_item("Set its category…", 4)
		_tree_context_menu.add_item("Hide this entry", 5)
		_tree_context_menu.add_item("Hide everything from %s" % definition.provider_id, 6)
		if EventSheetVocabularyCatalog.provenance_of(definition) == "curated":
			_tree_context_menu.add_item("Reset to the inferred name", 7)
	_tree_context_menu.add_separator()
	_tree_context_menu.add_item("Copy annotation stub", 1)
	_tree_context_menu.add_item("Copy registrar snippet", 2)
	_tree_context_menu.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))


## A stub whose dialect cannot express everything this ACE does leads with plain `#` notes
## (per-row state, a multi-line template, node scoping, looping, a starting value). Those notes
## are the part a reader most needs and the part most easily pasted past, so the status line
## says they are there.
static func _stub_note_hint(stub_text: String) -> String:
	if not stub_text.begins_with("#") or stub_text.begins_with("##"):
		return ""
	return " Read the # notes on top first - this one needs more than the dialect can declare."


## One-field prompt used by the rename / recategorize actions. Built with the shared popup
## helpers so it reads like every other dialog, and committed on Enter or OK.
func _prompt_override(definition: ACEDefinition, field: String, title: String, seed_value: String) -> void:
	var window: AcceptDialog = AcceptDialog.new()
	window.title = title
	window.ok_button_text = "Apply"
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var edit: LineEdit = LineEdit.new()
	edit.text = seed_value
	edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(320.0), 0.0)
	edit.select_all()
	box.add_child(EventSheetPopupUI.hint_label(
		"Stored in this project's vocabulary catalog - your script is not touched.", 320.0))
	box.add_child(edit)
	window.add_child(EventSheetPopupUI.margined(box))
	var commit: Callable = func() -> void:
		# Confirming without changing anything must not stamp the verb "renamed by you" -
		# that badge is a claim about the user's intent, and an unchanged field states none.
		if edit.text == seed_value:
			window.queue_free()
			return
		EventSheetVocabularyCatalog.set_override(definition.provider_id, definition.id, {field: edit.text})
		_refresh_tree()
		if _info_label != null:
			_info_label.text = "Updated %s - right-click it again to reset, or delete eventsheet_vocabulary.tres to undo every override." % definition.display_name
		window.queue_free()
	window.confirmed.connect(commit)
	edit.text_submitted.connect(func(_text: String) -> void: commit.call(); window.hide())
	window.canceled.connect(func() -> void: window.queue_free())
	_window.add_child(window)
	window.popup_centered()
	edit.grab_focus()


func _on_tree_context_menu_pressed(item_id: int) -> void:
	var definition: ACEDefinition = _tree_context_definition
	if definition == null:
		return
	match item_id:
		0:
			var pinned: bool = toggle_favorite(definition.provider_id, definition.id)
			if _info_label != null:
				_info_label.text = ("⭐ Pinned %s to Favorites" if pinned else "Unpinned %s from Favorites") % definition.display_name
			if _favorite_button != null and _selected_definition == definition:
				_favorite_button.set_pressed_no_signal(pinned)
			_refresh_side_panes()
		1:
			var comment_stub: String = EventSheetACEAnnotationStub.comment_stub(definition)
			DisplayServer.clipboard_set(comment_stub)
			if _info_label != null:
				_info_label.text = "Copied the ## @ace_* stub for %s - paste it into a provider script.%s" % [definition.display_name, _stub_note_hint(comment_stub)]
		2:
			var registrar_stub: String = EventSheetACEAnnotationStub.registrar_stub(definition)
			DisplayServer.clipboard_set(registrar_stub)
			if _info_label != null:
				_info_label.text = "Copied the registrar snippet for %s - paste it into a provider script.%s" % [definition.display_name, _stub_note_hint(registrar_stub)]
		3:
			_prompt_override(definition, "display_name", "Rename entry", definition.display_name)
		4:
			_prompt_override(definition, "category", "Set category", definition.category)
		5:
			EventSheetVocabularyCatalog.set_override(definition.provider_id, definition.id, {"hidden": true})
			_refresh_tree()
			if _info_label != null:
				_info_label.text = "Hid %s - delete eventsheet_vocabulary.tres to restore every hidden entry." % definition.display_name
		6:
			EventSheetVocabularyCatalog.set_class_excluded(definition.provider_id, true)
			_populate_object_cards()
			_refresh_tree()
			if _info_label != null:
				_info_label.text = "Hid everything from %s." % definition.provider_id
		7:
			# Clearing every field drops the entry, which restores the inferred identity.
			EventSheetVocabularyCatalog.set_override(definition.provider_id, definition.id,
				{"display_name": null, "category": null, "hidden": null})
			_refresh_tree()
			if _info_label != null:
				_info_label.text = "Reset %s to its inferred name." % definition.id


## Enter in the search box applies the first concrete match - type-and-Enter, no mouse.
## Depth-first so sub-category folders (root → parent → sub → entry) are reached too.
## Picker speed: pre-select the first concrete ACE so the description panel + Add button
## populate immediately and arrow/Enter work without a first click (type → glance → Enter).
func _select_first_match() -> void:
	if _tree == null:
		return
	var best: TreeItem = _best_match_item()
	if best != null:
		best.select(0)
		_tree.scroll_to_item(best)


func _activate_first_match() -> void:
	var best: TreeItem = _best_match_item()
	if best != null:
		best.select(0)
		_on_item_activated()


## Depth-first search for the first tree item carrying an ACEDefinition (a real ACE row),
## descending through group / sub-group folders (which carry no metadata of their own).
func _first_definition_item(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_metadata(0) is ACEDefinition:
			return child
		var nested: TreeItem = _first_definition_item(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null


## The type-and-Enter target: the highest RELEVANCE-scored row for the current query, not merely the
## first row in tree order (which, under category grouping, can bury the obvious match - typing "hide"
## should pre-select Hide). Falls back to the first definition row when the query is empty or nothing
## scores textually (a pure synonym/fuzzy hit), so behaviour is unchanged for empty/loose queries.
func _best_match_item() -> TreeItem:
	if _tree == null:
		return null
	var first: TreeItem = _first_definition_item(_tree.get_root())
	var query: String = _search.text.strip_edges() if _search != null else ""
	if query.is_empty():
		# No query means the sections are collapsed (first-open state): auto-selecting a row
		# INSIDE a collapsed section is invisible and would arm Enter/Add on something the user
		# never saw. Let the first pick be deliberate.
		return null
	var best: TreeItem = null
	var best_score: int = 0
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var node: TreeItem = stack.pop_back()
		var child: TreeItem = node.get_first_child()
		while child != null:
			# Guard before casting: section headers carry a Dictionary marker, and casting a
			# non-Object to a typed object variable is a runtime error, not a null.
			var child_meta: Variant = child.get_metadata(0)
			if child_meta is ACEDefinition:
				var score: int = _score_match(query, child_meta as ACEDefinition)
				if score > best_score:
					best_score = score
					best = child
			stack.push_back(child)
			child = child.get_next()
	# Reactivity steering: pre-select a polling condition's reactive twin (when it was surfaced in the
	# list) instead of the poll - unless the user typed the condition's exact name. Ties the Enter-target
	# to the Godot idiom (overlap -> On Body Entered) without touching the visible list order.
	if best != null:
		var best_meta: Variant = best.get_metadata(0)
		var best_definition: ACEDefinition = best_meta if best_meta is ACEDefinition else null
		if _prefer_reactive_twin(query, best_definition):
			var twin_item: TreeItem = _find_definition_item(best_definition.provider_id, _reactive_twin_id(best_definition))
			if twin_item != null:
				return twin_item
	return best if best != null else first


## The reactive trigger id that replaces a polling condition (from the shared ACEDescriptor.REACTS_TO
## map), or "" if the condition has no clean signal twin.
static func _reactive_twin_id(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	return str(ACEDescriptor.reactive_alternative(definition.provider_id, definition.id).get("trigger_id", ""))


## True when the picker should pre-select a condition's reactive twin instead of the condition: it has
## a twin AND the user did not type the condition's exact display name - so an explicit pick of the
## poll is respected, while a concept query ("overlap") lands on the reactive trigger.
static func _prefer_reactive_twin(query: String, definition: ACEDefinition) -> bool:
	if definition == null or _reactive_twin_id(definition).is_empty():
		return false
	return query.to_lower().strip_edges() != definition.display_name.to_lower().strip_edges()


## The tree item whose definition matches provider+id (the surfaced reactive twin), or null.
func _find_definition_item(provider_id: String, ace_id: String) -> TreeItem:
	if _tree == null:
		return null
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var node: TreeItem = stack.pop_back()
		var child: TreeItem = node.get_first_child()
		while child != null:
			var child_meta: Variant = child.get_metadata(0)
			if child_meta is ACEDefinition and (child_meta as ACEDefinition).provider_id == provider_id and (child_meta as ACEDefinition).id == ace_id:
				return child
			stack.push_back(child)
			child = child.get_next()
	return null


## Relevance of one row against a whole typed sentence (higher = better), so type-and-Enter targets
## what the reader meant. Every WORD has to hit something - the row's name, the node it is aimed at,
## its category or keywords - and each hit scores by how squarely it lands, which is what lets
## "boss fla 0.4" pick out Boss's Flash verb over everything else the three words touch. A VALUE in
## the query nudges the rows that have somewhere to put it. The reading itself is
## EventSheetQuickAdd, pure and pinned by a table there.
static func _score_match(query: String, definition: ACEDefinition) -> int:
	if definition == null:
		return 0
	var scored: int = EventSheetQuickAdd.score(query, definition.display_name,
		str(definition.metadata.get(SCENE_TARGET_META, "")), definition.get_search_text())
	if scored <= 0:
		return 0
	return scored + EventSheetQuickAdd.value_bonus(query, definition.parameters)


func _on_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	# Double-clicking a section header must fold/unfold, not crash: headers carry a Dictionary
	# marker, and casting a non-Object to an object type is a runtime error.
	var item_meta: Variant = item.get_metadata(0) if item != null else null
	if item_meta is Dictionary and (item_meta as Dictionary).has("blank_event"):
		_commit_blank_event()
		return
	if item_meta is Dictionary and (item_meta as Dictionary).has("alias_index"):
		_commit_alias(int((item_meta as Dictionary)["alias_index"]))
		return
	_commit_definition(item_meta if item_meta is ACEDefinition else null)


## The alias rows, in the section their descriptor already lives in, right after it. Only
## shown when the query matches them (or nothing is typed), and only in a mode that would take the
## descriptor anyway - an alias must never offer a condition where only actions can go.
func _add_alias_rows(root: TreeItem, group_nodes: Dictionary, mode: String, signals_only: bool,
		query: String) -> void:
	var lowered: String = query.strip_edges().to_lower()
	for alias_index: int in range(VARIABLE_ALIASES.size()):
		var alias: Dictionary = VARIABLE_ALIASES[alias_index]
		if not lowered.is_empty() and not str(alias.get("search", "")).contains(lowered) \
				and not str(alias.get("display", "")).to_lower().contains(lowered):
			continue
		var definition: ACEDefinition = _alias_definition(alias)
		if definition == null or not _is_allowed_for_mode(definition, mode, signals_only):
			continue
		var group_item: TreeItem = _resolve_group_item(root, group_nodes, _category_of(definition), false)
		var item: TreeItem = _tree.create_item(group_item)
		item.set_text(0, EventSheetL10n.translate(str(alias.get("display", ""))))
		var item_icon: Texture2D = resolve_definition_icon(definition)
		if item_icon != null:
			item.set_icon(0, item_icon)
			item.set_icon_max_width(0, 16)
		# The tooltip says what it IS, because two names for one row is exactly the thing a reader
		# will otherwise wonder about the first time they meet it.
		item.set_tooltip_text(0, EventSheetL10n.translate("%s, with the boolean half already filled in.")
			% definition.display_name)
		item.set_metadata(0, {"alias_index": alias_index})


## The shipped descriptor an alias row stands for, or null when the provider is not loaded.
func _alias_definition(alias: Dictionary) -> ACEDefinition:
	if _registry == null:
		return null
	return _registry.find_definition(str(alias.get("provider", "")), str(alias.get("ace_id", "")))


func _commit_alias(alias_index: int) -> void:
	if alias_index < 0 or alias_index >= VARIABLE_ALIASES.size():
		return
	var alias: Dictionary = VARIABLE_ALIASES[alias_index]
	var definition: ACEDefinition = _alias_definition(alias)
	if definition == null:
		return
	_pending_alias_prefill = (alias.get("prefill", {}) as Dictionary).duplicate()
	_commit_definition(definition)


## A compact single-column Tree for the ⭐ Favorites / ★ Recent side panes (Create-Node style).
func _make_side_tree() -> Tree:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 1
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, 80.0)
	# Transparent tree background so the panel_section card fill behind it reads as the pane background.
	tree.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tree.item_selected.connect(_on_side_item_selected.bind(tree))
	tree.item_activated.connect(_on_side_item_activated.bind(tree))
	return tree


## A side pane's body - its title label stacked above the list - as one VBox to drop into a
## panel_section() card, so each of Favorites / Recent reads as a self-contained titled panel.
func _titled_pane(title: Label, list: Tree) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(title)
	box.add_child(list)
	return box


## Fills the Favorites + Recent panes from the persisted lists, filtered to the current mode.
func _refresh_side_panes() -> void:
	if _favorites_list == null or _recent_list == null or _registry == null:
		return
	var mode: String = str(_context.get("mode", "new_event"))
	var signals_only: bool = bool(_context.get("signals_only", false))
	_populate_side_pane(_favorites_list, favorite_ids(), mode, signals_only)
	_populate_side_pane(_recent_list, _recent_ace_ids, mode, signals_only)


func _populate_side_pane(tree: Tree, keys: PackedStringArray, mode: String, signals_only: bool) -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	for key: String in keys:
		for candidate: ACEDefinition in _registry.get_all_definitions():
			if "%s/%s" % [candidate.provider_id, candidate.id] != key:
				continue
			if not _is_allowed_for_mode(candidate, mode, signals_only):
				break
			var item: TreeItem = tree.create_item(root)
			item.set_text(0, _item_label(candidate))
			var icon: Texture2D = resolve_definition_icon(candidate)
			if icon != null:
				item.set_icon(0, icon)
				item.set_icon_max_width(0, 16)
			# Favorites/Recent render plain like the main tree (Create-New-Node style): the per-row
			# icon carries the type, so no foreground tint on the label - consistent with the node picker.
			item.set_tooltip_text(0, _item_tooltip(candidate))
			item.set_metadata(0, candidate)
			break
	# An empty pane teaches how to fill it instead of sitting silently blank - a first-timer
	# otherwise reads two empty boxes as broken UI.
	if root.get_child_count() == 0:
		var hint_item: TreeItem = tree.create_item(root)
		hint_item.set_text(0, "Right-click any entry to pin it here." if tree == _favorites_list else "Entries you use appear here.")
		hint_item.set_selectable(0, false)
		hint_item.set_custom_color(0, _muted_header_color())
		hint_item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)


func _on_side_item_selected(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	var definition: ACEDefinition = item.get_metadata(0) as ACEDefinition if item != null else null
	if definition == null:
		return
	# One logical selection across the three trees: clear the others.
	if _tree != null:
		_tree.deselect_all()
	var other: Tree = _recent_list if tree == _favorites_list else _favorites_list
	if other != null:
		other.deselect_all()
	_on_definition_selected(definition)


func _on_side_item_activated(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	_commit_definition(item.get_metadata(0) as ACEDefinition if item != null else null)


## Unified selection: the highlighted ACE (tree or side pane) drives the description panel, the
## ⭐ button state, and what Add / Enter will insert.
func _on_definition_selected(definition: ACEDefinition) -> void:
	_selected_definition = definition
	_update_info_panel(definition)
	if _add_button != null:
		_add_button.disabled = definition == null
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(definition != null and _is_favorite(definition))


func _is_favorite(definition: ACEDefinition) -> bool:
	return favorite_ids().has("%s/%s" % [definition.provider_id, definition.id])


## Create-Node-style description panel: name, type + category, what it does, and its codegen.
func _update_info_panel(definition: ACEDefinition) -> void:
	_update_guide_button(definition)
	if _info_label == null:
		return
	if definition == null:
		_info_label.text = ""
		return
	var description: String = EventSheetL10n.translate(definition.description if not definition.description.is_empty() else str(definition.metadata.get("display_template", definition.display_name)))
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.is_empty():
		# Instance-backed reflected methods bake their owned-instance call at APPLY time -
		# preview the same call so "ships as" is never blank for a working ACE.
		template = definition.instance_backed_template()
	var header_line: String = "[b]%s[/b]  ·  %s  ·  %s" % [definition.display_name, _ace_type_label(definition.ace_type), _category_of(definition)]
	var body: String = header_line + "\n" + description
	if not template.is_empty():
		# Visible-but-muted: keep the "it's just GDScript" codegen, de-emphasized below the description.
		body += "\n[color=#%s]→ [code]%s[/code][/color]" % [_muted_header_color().to_html(false), template]
	# Reactivity nudge: a polling condition that has a clean signal twin gets a one-line tip pointing at
	# the reactive trigger (the Godot idiom). Informational only - the condition stays fully pickable.
	var reactive: Dictionary = ACEDescriptor.reactive_alternative(definition.provider_id, definition.id)
	if not reactive.is_empty():
		body += "\n[color=#e0b050]💡 Reactive alternative: [b]%s[/b] - reacts once when it happens, instead of checking every frame.[/color]" % str(reactive.get("trigger_name", ""))
	# The footer under a variable verb: every variable it can take, each in the sentence its row
	# reads with, so the choice is made from the sheet's own words instead of from a bare name.
	var sentences: String = variable_sentences_footer(_variables_in_scope(), definition)
	if not sentences.is_empty():
		body += "\n[color=#%s]%s[/color]" % [_muted_header_color().to_html(false), sentences]
	_info_label.text = body


## The variable verbs' footer: one line per variable the highlighted verb can take, written the
## way its row is ("Instance whole number hp = 100   Current health."). "" for every other verb.
## Static + pure, so the footer is pinned without a dialog.
static func variable_sentences_footer(entries: Array[Dictionary], definition: ACEDefinition) -> String:
	if definition == null or definition.category != VARIABLES_CATEGORY:
		return ""
	if not EventSheetVariableOwners.VARIABLE_VERB_ORDER.has(str(definition.id)):
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetVariableOwners.variables_for_verb(entries, str(definition.id)):
		lines.append("%s  %s" % [
			str(entry.get("owner", "")), EventSheetVariableOwners.sentence(entry)])
	return "\n".join(lines)


## Sets the "read more" affordance's label provider: a Callable taking an ACEDefinition and
## returning the button text ("Open Quest's guide"), or "" for no button. Left unset, the picker
## shows no affordance at all - so the seam costs nothing until a docs surface fills it.
func set_guide_label_provider(provider: Callable) -> void:
	_guide_label_provider = provider


## The "Open <Pack>'s guide" link under the description: shown only when the label provider
## names a guide for this verb (a pack verb), hidden for builtin verbs, sections and no selection.
func _update_guide_button(definition: ACEDefinition) -> void:
	if _guide_button == null:
		return
	var guide_label: String = ""
	if definition != null and _guide_label_provider.is_valid():
		guide_label = str(_guide_label_provider.call(definition))
	_guide_button.text = guide_label
	_guide_button.visible = not guide_label.is_empty()


func _on_figure_guide_requested() -> void:
	if _selected_definition != null:
		guide_requested.emit(_selected_definition)


## Selecting a section header shows the group's description instead of an ACE: Add stays disabled,
## and the blurb comes from EventSheetSectionInfo, falling back to a pack's own class doc comment
## (the first provider_description among the group's rows), then to a generic line.
func _show_section_info(item: TreeItem, section_name: String) -> void:
	_selected_definition = null
	# A section is a group of verbs, not a pack verb - no guide link.
	_update_guide_button(null)
	if _add_button != null:
		_add_button.disabled = true
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(false)
	if _info_label == null:
		return
	var blurb: String = EventSheetSectionInfo.description_for(section_name)
	if blurb.is_empty():
		blurb = _provider_description_in(item)
	if blurb.is_empty():
		blurb = "[color=#%s]A group of related actions, conditions, and expressions.[/color]" % _muted_header_color().to_html(false)
	_info_label.text = "[b]%s[/b]  ·  section\n%s" % [section_name, blurb]


## The first provider_description among a section's ACE rows (a pack's class doc comment), or "".
## Descends through any sub-section folders (which carry a marker Dictionary, not an ACEDefinition).
func _provider_description_in(item: TreeItem) -> String:
	var child: TreeItem = item.get_first_child()
	while child != null:
		var meta: Variant = child.get_metadata(0)
		if meta is ACEDefinition:
			var provider_desc: String = str((meta as ACEDefinition).metadata.get("provider_description", ""))
			if not provider_desc.is_empty():
				return provider_desc
		elif meta is Dictionary:
			var nested: String = _provider_description_in(child)
			if not nested.is_empty():
				return nested
		child = child.get_next()
	return ""


func _on_favorite_button_pressed() -> void:
	if _selected_definition == null:
		_favorite_button.set_pressed_no_signal(false)
		return
	var pinned: bool = toggle_favorite(_selected_definition.provider_id, _selected_definition.id)
	_favorite_button.set_pressed_no_signal(pinned)
	_refresh_side_panes()


func _on_add_button_pressed() -> void:
	# The blank first entry carries no definition, so Add / Enter commit it directly.
	if _blank_event_highlighted and _selected_definition == null:
		_commit_blank_event()
		return
	_commit_definition(_selected_definition)


## Picking one of the open script's functions: find its Call Function definition and commit that -
## same path as every other entry, so undo, recents and the params dialog behave identically.
func _commit_function_call(function_name: String) -> void:
	for definition: ACEDefinition in function_call_definitions(_open_sheet(), _registry):
		if str(definition.metadata.get(FUNCTION_META_KEY, "")) == function_name:
			_commit_definition(definition)
			return


## Single commit path for the tree, the side panes, and the Add button.
func _commit_definition(definition: ACEDefinition) -> void:
	if definition == null:
		return
	# Read before the window closes: the sentence the reader typed is what carries the values, and
	# "boss fla 0.4" means the 0.4 as much as it means the verb.
	var typed: String = _search.text.strip_edges() if _search != null else ""
	close()
	note_recent(definition.provider_id, definition.id)
	var context: Dictionary = _context.duplicate(true)
	# A Functions entry is a Call Function row whose target is already chosen, so the params dialog
	# opens on the ARGUMENTS instead of asking again which function was meant.
	var target_function: String = str(definition.metadata.get(FUNCTION_META_KEY, ""))
	if not target_function.is_empty():
		var initial_values: Dictionary = context.get("existing_params", {})
		initial_values["function_name"] = target_function
		context["existing_params"] = initial_values
	# A shelf entry is the ordinary node-scoped row with its target already chosen, so
	# the params dialog opens on the value instead of asking again which node was meant.
	var aimed_light: String = str(definition.metadata.get(SCENE_TARGET_META, ""))
	if not aimed_light.is_empty():
		var light_values: Dictionary = context.get("existing_params", {})
		light_values["target"] = aimed_light
		# And whatever else the shelf answered on the reader's behalf - the dial an effect entry was
		# built for, so the dialog opens on the value rather than asking for the name back.
		light_values.merge(definition.metadata.get(SCENE_PREFILL_META, {}) as Dictionary, true)
		context["existing_params"] = light_values
	# An alias row is the same descriptor with the boolean half of the form already answered.
	# Taken (and cleared) here rather than stamped on the definition, because ACEDefinitions are
	# shared across every tab for the session and must never carry one row's values.
	if not _pending_alias_prefill.is_empty():
		var alias_values: Dictionary = context.get("existing_params", {})
		alias_values.merge(_pending_alias_prefill, true)
		context["existing_params"] = alias_values
		_pending_alias_prefill = {}
	# And the values the query itself carried: a number or a quoted string in the search box lands
	# in the first parameter that can take it and is not already answered, so the parameters dialog
	# opens with it in place. Last, so nothing the picker chose deliberately is overwritten.
	var answered: Dictionary = context.get("existing_params", {})
	var from_query: Dictionary = EventSheetQuickAdd.prefill(typed, definition.parameters, answered)
	if not from_query.is_empty():
		answered.merge(from_query, true)
		context["existing_params"] = answered
	ace_selected.emit(definition, context)


func close() -> void:
	if _window == null:
		return
	_window.hide()


func is_open() -> bool:
	return _window != null and _window.visible


func get_popup_rect() -> Rect2:
	if _window == null:
		return Rect2()
	return Rect2(Vector2(_window.position), Vector2(_window.size))
