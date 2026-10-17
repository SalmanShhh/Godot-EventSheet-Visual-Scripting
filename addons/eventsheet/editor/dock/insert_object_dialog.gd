@tool
extends RefCounted
# Insert new object: a new script class is made the way a new object is inserted into a game. Pick
# what it is from tiles grouped by kind (or from the class tree, the way Godot's Create New Node
# lists it), name it, and Insert writes `<name>.gd` with its class line and opens it as a sheet.
#
#   Search object types…                      Grid | List
#   Favorites  CharacterBody2D  Area2D
#   2D         [Character] [Sprite] [Area] [Physics body] [2D node]
#   3D         …
#   Character - A body you move with code: players and enemies that walk, jump and collide.
#   Name                [Player            ]
#   [ ] Runs in the editor - a tool: its code runs while you edit (@tool)
#   class_name Player / extends CharacterBody2D
#   Creates player.gd in res://                               Insert  Cancel
#
# Favorites and Recent are Godot's own lists from the Create New Node dialog, read as they are; Insert
# puts its class at the top of Recent, the way Create New Node does, so both windows remember it.
# Search reaches every class a script can extend, not only the tiles.
#
# DELIBERATELY NO `class_name`: the dock reaches it with `load()` of its path when the window is
# asked for, so nothing about it compiles on the boot or first-open path.

## The class tree in list view stops climbing at these: above them there is nothing to extend.
const TREE_ROOTS: PackedStringArray = ["Node", "Resource", "RefCounted"]
## The class the window lands on when it opens.
const DEFAULT_CLASS := "CharacterBody2D"
## Where Godot keeps its Create New Node lists (favorites.Node, create_recent.Node), and how many
## classes its Recent list holds.
const GODOT_LISTS_FOLDER := "res://.godot/editor"
const RECENT_LENGTH := 15

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _search: LineEdit = null
var _grid_box: VBoxContainer = null
var _tree: Tree = null
var _view_buttons: Array[Button] = []
var _chosen_label: Label = null
var _name_edit: LineEdit = null
var _tool_check: CheckBox = null
var _head_box: VBoxContainer = null
var _problem: EventSheetPopupUI.StateNote = null
var _target_label: Label = null
var _directory: String = "res://"
var _chosen: String = DEFAULT_CLASS


## The tiles, grouped by kind: [group words, [[class, label, description], ...]]. Every word is
## spelled inside its own translate() call so the translation harvest finds it.
static func catalog() -> Array:
	return [
		[EventSheetL10n.translate("2D"), [
			["CharacterBody2D", EventSheetL10n.translate("Character"), EventSheetL10n.translate("A body you move with code: players and enemies that walk, jump and collide.")],
			["Sprite2D", EventSheetL10n.translate("Sprite"), EventSheetL10n.translate("A picture on screen.")],
			["Area2D", EventSheetL10n.translate("Area"), EventSheetL10n.translate("Detects what enters or leaves it: pickups, triggers, hit boxes.")],
			["RigidBody2D", EventSheetL10n.translate("Physics body"), EventSheetL10n.translate("Moved by physics: crates, balls, debris.")],
			["Node2D", EventSheetL10n.translate("2D node"), EventSheetL10n.translate("A plain 2D object with a position, for anything else.")],
		]],
		[EventSheetL10n.translate("3D"), [
			["CharacterBody3D", EventSheetL10n.translate("Character 3D"), EventSheetL10n.translate("A 3D body you move with code.")],
			["MeshInstance3D", EventSheetL10n.translate("Mesh"), EventSheetL10n.translate("A 3D model in the world.")],
			["Area3D", EventSheetL10n.translate("Area 3D"), EventSheetL10n.translate("Detects what enters or leaves a 3D space.")],
			["Camera3D", EventSheetL10n.translate("Camera 3D"), EventSheetL10n.translate("A 3D camera.")],
			["Node3D", EventSheetL10n.translate("3D node"), EventSheetL10n.translate("A plain 3D object with a position.")],
		]],
		[EventSheetL10n.translate("User interface"), [
			["Control", EventSheetL10n.translate("UI element"), EventSheetL10n.translate("A box on the screen for menus and HUD.")],
			["Button", EventSheetL10n.translate("Button"), EventSheetL10n.translate("A clickable button.")],
			["Label", EventSheetL10n.translate("Text"), EventSheetL10n.translate("Text on the screen.")],
			["CanvasLayer", EventSheetL10n.translate("HUD layer"), EventSheetL10n.translate("Draws its children on top of the game, like a HUD.")],
			["Panel", EventSheetL10n.translate("Panel"), EventSheetL10n.translate("A background box for a menu.")],
		]],
		[EventSheetL10n.translate("Data and project"), [
			["Resource", EventSheetL10n.translate("Data file"), EventSheetL10n.translate("A .tres data asset: stats, waves, loot tables.")],
			["Node", EventSheetL10n.translate("Logic only"), EventSheetL10n.translate("No position, just logic: a manager or controller.")],
			["EditorScript", EventSheetL10n.translate("Editor tool"), EventSheetL10n.translate("A script that runs inside the editor.")],
			["PointLight2D", EventSheetL10n.translate("Light"), EventSheetL10n.translate("A 2D light.")],
		]],
	]


## The [label, description] a class is offered with: its tile's words, or the class itself with a
## plain sentence for one found by search.
static func words_for(class_id: String) -> Array:
	for group: Array in catalog():
		for item: Array in group[1]:
			if str(item[0]) == class_id:
				return [str(item[1]), str(item[2])]
	return [class_id, EventSheetL10n.translate("Everything a %s can do, and what you add to it.") % class_id]


## True when a script of this class has to run in the editor: an EditorScript is nothing else.
static func forces_tool(class_id: String) -> bool:
	return class_id == "EditorScript"


## What stops Insert for this name in this folder, as the sentence the window says, or "" when
## nothing does.
static func name_problem(typed: String, directory: String) -> String:
	var wanted: String = typed.strip_edges()
	if wanted.is_empty():
		return EventSheetL10n.translate("Name it to insert it.")
	if not EventSheetIdentifierRules.is_valid(wanted):
		return EventSheetL10n.translate("\"%s\" cannot be a class name.") % wanted
	if EventSheetHeadActions.class_name_taken(wanted):
		return EventSheetL10n.translate("\"%s\" is already the name of another class.") % wanted
	if FileAccess.file_exists(directory.path_join(file_name_for(wanted))):
		return EventSheetL10n.translate("%s is already in this folder.") % file_name_for(wanted)
	return ""


## The file a class name is written to: its words in snake_case, the way Godot names a script.
static func file_name_for(class_id: String) -> String:
	return class_id.strip_edges().to_snake_case() + ".gd"


## The sheet Insert writes: nothing in it yet but what the class IS.
static func sheet_for(class_id: String, typed_name: String, tool_on: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = class_id
	sheet.custom_class_name = typed_name.strip_edges()
	sheet.tool_mode = tool_on or forces_tool(class_id)
	return sheet


## The top of the file Insert writes, exactly as the compiler writes it.
static func file_head(class_id: String, typed_name: String, tool_on: bool) -> String:
	return str(SheetCompiler.echo(sheet_for(class_id, typed_name, tool_on), true).get("output", "")).strip_edges()


## The class tree list view shows for `classes`: each with every ancestor up to a root, in tree
## order, as [class, depth, pickable]. An ancestor nothing can be made of (CanvasItem, PhysicsBody2D)
## is in the tree to read and is not pickable, the way Godot's own dialog greys it.
static func tree_rows(classes: PackedStringArray) -> Array:
	var children: Dictionary = {}
	var roots: PackedStringArray = PackedStringArray()
	for class_id: String in classes:
		var current: String = class_id
		while ClassDB.class_exists(current) and not TREE_ROOTS.has(current):
			var parent: String = ClassDB.get_parent_class(current)
			if parent.is_empty():
				break
			var under: PackedStringArray = children.get(parent, PackedStringArray())
			if not under.has(current):
				under.append(current)
				children[parent] = under
			current = parent
		if not roots.has(current):
			roots.append(current)
	var rows: Array = []
	for root: String in roots:
		_append_tree(rows, root, 0, children)
	return rows


static func _append_tree(rows: Array, class_id: String, depth: int, children: Dictionary) -> void:
	var pickable: bool = not ClassDB.class_exists(class_id) or ClassDB.can_instantiate(class_id) or class_id == "EditorScript"
	rows.append([class_id, depth, pickable])
	var under: PackedStringArray = children.get(class_id, PackedStringArray())
	under.sort()
	for child: String in under:
		_append_tree(rows, child, depth + 1, children)


## Godot's own favorites or recent classes from its Create New Node dialog (`which` is "favorites"
## or "create_recent"), as written there, keeping only classes a script here can extend.
static func godot_class_list(which: String, folder: String = GODOT_LISTS_FOLDER) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var path: String = folder.path_join("%s.Node" % which)
	if not FileAccess.file_exists(path):
		return found
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var class_id: String = line.strip_edges()
		if ClassDB.class_exists(class_id) and ClassDB.can_instantiate(class_id) and not found.has(class_id):
			found.append(class_id)
	return found


## Puts a node class at the top of Godot's own Recent list, the way Create New Node does when a node
## is made there: newest first, each class once, fifteen at most, every other line kept as written.
## A class that is not a node is left out, because that list only offers nodes.
static func remember_recent(class_id: String, folder: String = GODOT_LISTS_FOLDER) -> void:
	if not ClassDB.class_exists(class_id) or not (class_id == "Node" or ClassDB.is_parent_class(class_id, "Node")):
		return
	var path: String = folder.path_join("create_recent.Node")
	var lines: PackedStringArray = PackedStringArray([class_id])
	if FileAccess.file_exists(path):
		for line: String in FileAccess.get_file_as_string(path).split("\n", false):
			if lines.size() < RECENT_LENGTH and line.strip_edges() != class_id:
				lines.append(line.strip_edges())
	DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")


## Opens the window over the dock, for a new class in `directory` - by default the folder the
## FileSystem dock has open, the way Godot's own Create New puts a file where you are looking.
func open(dock: Control, directory: String = "") -> ConfirmationDialog:
	_dock = dock
	if directory.is_empty() and Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		directory = EditorInterface.get_current_directory()
	_directory = directory if directory.begins_with("res://") else "res://"
	_build()
	_fill()
	_choose(DEFAULT_CLASS)
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(roundi(EventSheetPalette.scaled_f(640.0)), 0))
		_search.grab_focus()
	return _dialog


## The class picked now, its name and the editor switch - what Insert will write.
func chosen() -> Dictionary:
	return {"class": _chosen, "name": _name_edit.text.strip_edges(), "tool": _tool_check.button_pressed}


func _build() -> void:
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("Insert new object"), Vector2i.ZERO,
		_dock, EventSheetL10n.translate("Insert"), _insert)
	_dialog = parts["window"]
	# The window keeps this helper alive for as long as it is open, and lets it go with itself.
	_dialog.set_meta("insert_object", self)
	# Each open is a new window that frees itself, so nothing from the last one leaks into the next.
	_dialog.visibility_changed.connect(func() -> void:
		if not _dialog.visible:
			_dialog.queue_free())
	var form: VBoxContainer = parts["box"]
	var top: HBoxContainer = HBoxContainer.new()
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("Search object types…")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _fill())
	top.add_child(_search)
	for view: Array in [[EventSheetL10n.translate("Grid"), EventSheetL10n.translate("Icons, grouped by kind")],
			[EventSheetL10n.translate("List"), EventSheetL10n.translate("The class tree, the way Godot's Create New Node lists it")]]:
		var button: Button = Button.new()
		button.text = str(view[0])
		button.tooltip_text = str(view[1])
		button.toggle_mode = true
		button.pressed.connect(_show_view.bind(_view_buttons.size()))
		_view_buttons.append(button)
		top.add_child(button)
	form.add_child(top)
	for which: Array in [["favorites", EventSheetL10n.translate("Favorites")], ["create_recent", EventSheetL10n.translate("Recent")]]:
		var listed: PackedStringArray = godot_class_list(str(which[0]))
		if listed.is_empty():
			continue
		var line: HBoxContainer = HBoxContainer.new()
		var lead: Label = EventSheetPopupUI.hint_label(str(which[1]), 0.0)
		lead.custom_minimum_size.x = EventSheetPalette.scaled_f(70.0)
		line.add_child(lead)
		for class_id: String in listed.slice(0, 6):
			var chip: Button = Button.new()
			chip.flat = true
			chip.text = class_id
			chip.icon = _class_icon(class_id)
			chip.pressed.connect(_choose.bind(class_id))
			line.add_child(chip)
		form.add_child(line)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(300.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_box)
	form.add_child(scroll)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(300.0))
	_tree.item_selected.connect(func() -> void: _choose(str(_tree.get_selected().get_metadata(0))))
	form.add_child(_tree)
	# The chosen kind's sentence stays on screen, not only in a tooltip.
	_chosen_label = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(600.0))
	form.add_child(_chosen_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Player"
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name when inserted"), _name_edit,
		EventSheetPopupUI.LABEL_MIN_WIDTH, EventSheetL10n.translate("The class name, exactly as code will write it. The file is named after it.")))
	_tool_check = CheckBox.new()
	_tool_check.text = EventSheetL10n.translate("Runs in the editor - a tool: its code runs while you edit (@tool)")
	_tool_check.toggled.connect(func(_on: bool) -> void: _refresh())
	form.add_child(_tool_check)
	_problem = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(600.0))
	form.add_child(_problem)
	_head_box = VBoxContainer.new()
	form.add_child(_head_box)
	_target_label = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(600.0))
	form.add_child(_target_label)
	_show_view(0)


## Grid (0) or List (1): the two views of the same choices.
func _show_view(index: int) -> void:
	for button_index: int in range(_view_buttons.size()):
		_view_buttons[button_index].set_pressed_no_signal(button_index == index)
	_grid_box.get_parent().visible = index == 0
	_tree.visible = index == 1


## The classes the search shows: the tiles that match it, then every other class a script can
## extend whose name starts with it.
func _matching() -> Array:
	var typed: String = _search.text.strip_edges().to_lower()
	var groups: Array = []
	var shown: PackedStringArray = PackedStringArray()
	for group: Array in catalog():
		var items: Array = []
		for item: Array in group[1]:
			if typed.is_empty() or str(item[0]).to_lower().contains(typed) or str(item[1]).to_lower().contains(typed):
				items.append(item)
				shown.append(str(item[0]))
		if not items.is_empty():
			groups.append([group[0], items])
	if not typed.is_empty():
		var found: Array = []
		for class_id: String in EventSheetSheetTypeDialog.host_candidates(typed):
			if not shown.has(class_id):
				var words: Array = words_for(class_id)
				found.append([class_id, class_id, words[1]])
		if not found.is_empty():
			groups.append([EventSheetL10n.translate("Other classes"), found])
	return groups


func _fill() -> void:
	for old: Node in Array(_grid_box.get_children()):
		_grid_box.remove_child(old)
		old.queue_free()
	var classes: PackedStringArray = PackedStringArray()
	for group: Array in _matching():
		_grid_box.add_child(EventSheetPopupUI.small_caps_label(str(group[0])))
		var tiles: ItemList = ItemList.new()
		tiles.icon_mode = ItemList.ICON_MODE_TOP
		tiles.max_columns = 0
		tiles.same_column_width = true
		tiles.fixed_column_width = roundi(EventSheetPalette.scaled_f(104.0))
		tiles.fixed_icon_size = Vector2i.ONE * roundi(EventSheetPalette.scaled_f(24.0))
		tiles.auto_height = true
		tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for item: Array in group[1]:
			var index: int = tiles.add_item(str(item[1]), _class_icon(str(item[0])))
			tiles.set_item_metadata(index, str(item[0]))
			tiles.set_item_tooltip(index, "%s: %s" % [item[0], item[2]])
			classes.append(str(item[0]))
		tiles.item_selected.connect(func(index: int) -> void: _choose(str(tiles.get_item_metadata(index))))
		_grid_box.add_child(tiles)
	_tree.clear()
	var parents: Array[TreeItem] = [_tree.create_item()]
	for row: Array in tree_rows(classes):
		var depth: int = int(row[1])
		parents.resize(depth + 1)
		var item: TreeItem = _tree.create_item(parents[depth])
		parents.append(item)
		item.set_text(0, str(row[0]))
		item.set_icon(0, _class_icon(str(row[0])))
		item.set_metadata(0, str(row[0]))
		item.set_selectable(0, bool(row[2]))
		item.set_tooltip_text(0, str(words_for(str(row[0]))[1]) if bool(row[2])
			else EventSheetL10n.translate("Nothing is made of this one itself: pick one of the classes under it."))
		if not bool(row[2]):
			item.set_custom_color(0, EventSheetPopupUI.muted_text_color())
	_mark_chosen()


## Picks a class: every view shows it chosen, and its sentence and the file head follow.
func _choose(class_id: String) -> void:
	if class_id.is_empty():
		return
	_chosen = class_id
	_mark_chosen()
	var words: Array = words_for(class_id)
	_chosen_label.text = "%s - %s" % [words[0], words[1]]
	_tool_check.disabled = forces_tool(class_id)
	if forces_tool(class_id):
		_tool_check.set_pressed_no_signal(true)
	_refresh()


func _mark_chosen() -> void:
	for child: Node in _grid_box.get_children():
		var tiles: ItemList = child as ItemList
		if tiles == null:
			continue
		tiles.deselect_all()
		for index: int in range(tiles.item_count):
			if str(tiles.get_item_metadata(index)) == _chosen:
				tiles.select(index)
	var item: TreeItem = _tree.get_root().get_first_child() if _tree.get_root() != null else null
	while item != null:
		if str(item.get_metadata(0)) == _chosen and not item.is_selected(0):
			item.select(0)
		item = item.get_next_in_tree()


## Says what Insert will write, or why it cannot yet, and lets Insert be pressed only for a name it
## would accept.
func _refresh() -> void:
	var typed: String = _name_edit.text.strip_edges()
	var problem: String = name_problem(typed, _directory)
	_problem.say(problem)
	EventSheetPopupUI.mark_field(_name_edit, not problem.is_empty() and not typed.is_empty())
	_dialog.get_ok_button().disabled = not problem.is_empty()
	for old: Node in Array(_head_box.get_children()):
		_head_box.remove_child(old)
		old.queue_free()
	_head_box.add_child(EventSheetPopupUI.code_card(file_head(_chosen, typed if not typed.is_empty() else "Player",
		_tool_check.button_pressed), EventSheetPalette.scaled_f(560.0)))
	_target_label.text = EventSheetL10n.translate("Creates %s in %s and opens it.") % [
		file_name_for(typed if not typed.is_empty() else "Player"), _directory]


func _insert() -> void:
	var picked: Dictionary = chosen()
	if not name_problem(str(picked["name"]), _directory).is_empty():
		return
	var result: Dictionary = EventSheetWorkflow.write_sheet_file(
		sheet_for(str(picked["class"]), str(picked["name"]), bool(picked["tool"])), _directory, str(picked["name"]))
	if not bool(result.get("ok", false)):
		_problem.say(str(result.get("message", "")))
		return
	_dialog.hide()
	remember_recent(str(picked["class"]))
	var path: String = str(result.get("sheet_path", ""))
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_resource_filesystem().scan()
	_dock._load_sheet_from_path(path)
	_dock._set_status(EventSheetL10n.translate("Inserted %s - a %s, in %s.") % [picked["name"], picked["class"], path.get_file()])


## The editor's own icon for a class, or none outside the editor.
func _class_icon(class_id: String) -> Texture2D:
	if _dock == null or not _dock.has_theme_icon(class_id, "EditorIcons"):
		return null
	return _dock.get_theme_icon(class_id, "EditorIcons")
