@tool
class_name EventSheetBehaviourLibraryWindow
extends ConfirmationDialog

# Behaviour library: the behaviours the plugin carries that this project does not hold yet.
#
# Every behaviour is a plain script with a class_name and an @icon, so once its folder is in the
# project Godot's own Create Node window lists it (Ctrl+A in the Scene dock) - that window is how a
# behaviour is added to a node, and this one does not repeat it. This window does the one job Godot
# cannot: the library sits in a folder Godot never imports (addons/eventsheet_library/), so a pack in
# it cannot be listed until its folder is copied into the project.
#
# Sheet > Behaviour library… opens it. Under the search each pack that is not in the project yet sits
# on a row: its icon, its name, a line saying what it is, and what else comes along because it needs
# it (read from its own @ace_requires). One button, "Add to project", copies the folders in and lets
# Godot import them; a line then says to add it with Add Child Node under the node it acts on. "In this
# project" lists the packs the project holds instead, and its button, "Remove from project…", asks
# first and sends the folder to the system trash.

## The pack folder this window is on, kept across a rebuild.
var _selected_dir: String = ""
var _packs: Array[Dictionary] = []
var _search: LineEdit = null
var _list: VBoxContainer = null
var _no_match: Label = null
var _scope_waiting: Button = null
var _scope_held: Button = null
var _guide_link: Button = null
var _said_band: Label = null
## (pack) -> {"ok", "message"}, awaited: copies a library pack in and imports it.
var _on_add: Callable = Callable()
## (pack) - Remove from project… on a pack the project holds.
var _on_remove: Callable = Callable()
## True while a copy is running, so a second click does not start another.
var _adding: bool = false


func _init() -> void:
	title = EventSheetL10n.translate("Behaviour library")
	ok_button_text = EventSheetL10n.translate("Add to project")
	# OK keeps the window open: it says what it copied in, then the list shows what is left.
	dialog_hide_on_ok = false
	cancel_button_text = EventSheetL10n.translate("Close")
	add_child(EventSheetPopupUI.margined(_build_body()))
	confirmed.connect(_on_confirmed)


## `on_add` (awaited) copies a library pack in; `on_remove` is Remove from project….
func configure(on_add: Callable, on_remove: Callable = Callable()) -> void:
	_on_add = on_add
	_on_remove = on_remove


## Opens the window. `preselect` is a pack folder to open on - the picker's suggestion and a
## behaviour's Manual page hand one over - and its name is put in the search so it shows first.
func open(preselect: String = "") -> void:
	_selected_dir = ""
	_said_band.text = ""
	_scope_waiting.set_pressed_no_signal(true)
	_scope_held.set_pressed_no_signal(false)
	_load_packs()
	_search.text = ""
	for pack: Dictionary in _packs:
		if not preselect.is_empty() and str(pack.get("dir", "")) == preselect:
			_search.text = str(pack.get("name", ""))
			_selected_dir = preselect
	_rebuild_list()
	EventSheetWindowPlacement.popup_centered(self, Vector2i(int(EventSheetPalette.scaled_f(620.0)), int(EventSheetPalette.scaled_f(560.0))))


## Reads the packs again and redraws the list - after a pack was added or removed.
func refresh() -> void:
	_load_packs()
	_rebuild_list()


## The packs the project holds and the packs only the library holds, each marked in "state".
func _load_packs() -> void:
	var waiting: Array[Dictionary] = []
	if EventSheetPackLibrary.exists():
		waiting = EventSheetPackLibrary.packs()
	_packs = EventSheetPackLibrary.combined(EventSheetPackCatalog.packs(), waiting)


func _has_library() -> bool:
	return EventSheetPackLibrary.exists()


## True for a pack that waits in the library rather than sitting in the project.
static func is_library_pack(pack: Dictionary) -> bool:
	return str(pack.get("state", "")) == "library"


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(560.0), EventSheetPalette.scaled_f(440.0))
	page.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Behaviours not in this project yet. Add one to the project, then add it to a node with Add Child Node (Ctrl+A) in the Scene dock."),
		EventSheetPalette.scaled_f(540.0)))
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("search")
	_search.right_icon = EventSheetPopupUI._editor_icon("Search")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _filter())
	var search_row: HBoxContainer = HBoxContainer.new()
	search_row.add_child(_search)
	# Not in this project (the ones to add) / In this project (the ones to remove).
	var scope: HBoxContainer = HBoxContainer.new()
	scope.add_theme_constant_override("separation", 0)
	var scope_group: ButtonGroup = ButtonGroup.new()
	_scope_waiting = Button.new()
	_scope_waiting.text = EventSheetL10n.translate("Not in this project")
	_scope_waiting.tooltip_text = EventSheetL10n.translate("The library's behaviours this project does not hold yet.")
	_scope_held = Button.new()
	_scope_held.text = EventSheetL10n.translate("In this project")
	_scope_held.tooltip_text = EventSheetL10n.translate("The behaviours this project already holds, to remove from it.")
	for scope_button: Button in [_scope_waiting, _scope_held]:
		scope_button.toggle_mode = true
		scope_button.button_group = scope_group
		scope_button.add_theme_color_override("font_pressed_color", EventSheetPopupUI.accent_color())
		scope_button.pressed.connect(func() -> void:
			_selected_dir = ""
			_rebuild_list())
		scope.add_child(scope_button)
	_scope_waiting.button_pressed = true
	search_row.add_child(scope)
	page.add_child(search_row)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(540.0), EventSheetPalette.scaled_f(300.0))
	list_scroll.add_child(_list)
	page.add_child(list_scroll)
	# The selected behaviour's guide, readable before it is added - from the project or the library.
	_guide_link = Button.new()
	_guide_link.flat = true
	_guide_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_guide_link.add_theme_color_override("font_color", EventSheetPopupUI.accent_color())
	_guide_link.tooltip_text = EventSheetL10n.translate("Opens this behaviour's guide in the Manual, so you can read it before adding it.")
	_guide_link.pressed.connect(_read_selected_guide)
	_guide_link.visible = false
	page.add_child(_guide_link)
	_said_band = Label.new()
	_said_band.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said_band.custom_minimum_size.x = EventSheetPalette.scaled_f(540.0)
	_said_band.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_OK))
	page.add_child(_said_band)
	return page


## True while the list shows the packs the project does not hold.
func _waiting_scope() -> bool:
	return _scope_waiting == null or _scope_waiting.button_pressed


## The packs the shown scope lists.
func _scoped_packs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pack: Dictionary in _packs:
		if is_library_pack(pack) == _waiting_scope():
			out.append(pack)
	return out


func _rebuild_list() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.free()
	var shown: Array[Dictionary] = _scoped_packs()
	shown.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return str(first.get("name", "")).naturalnocasecmp_to(str(second.get("name", ""))) < 0)
	for pack: Dictionary in shown:
		_list.add_child(_build_row(pack))
	_no_match = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(520.0))
	_list.add_child(_no_match)
	_filter()


## Shows the rows the search matches. The selection moves to the first match when the one chosen is
## hidden, so the button always acts on a row in view.
func _filter() -> void:
	var matching: Dictionary = {}
	for pack: Dictionary in EventSheetPackCatalog.filtered(_scoped_packs(), "", _search.text if _search != null else ""):
		matching[str(pack.get("dir", ""))] = true
	var first_shown: String = ""
	var still_shown: bool = false
	for row: Node in _list.get_children():
		if not row is Button:
			continue
		var pack_dir: String = str(row.get_meta("pack_dir"))
		(row as Button).visible = matching.has(pack_dir)
		if (row as Button).visible:
			first_shown = pack_dir if first_shown.is_empty() else first_shown
			still_shown = still_shown or pack_dir == _selected_dir
	if _no_match != null:
		_no_match.visible = matching.is_empty()
		_no_match.text = _empty_words()
	_select(_selected_dir if still_shown else first_shown)


## What the list says when it has nothing to show.
func _empty_words() -> String:
	if not _has_library() and _waiting_scope():
		return EventSheetL10n.translate("This install carries no behaviour library.")
	if _scoped_packs().is_empty():
		return EventSheetL10n.translate("Every behaviour in the library is already in this project.") if _waiting_scope() \
			else EventSheetL10n.translate("This project holds no behaviours yet.")
	return EventSheetL10n.translate("No behaviour here matches that.")


## The rows of the shown scope, in the order they read.
func rows() -> Array[Button]:
	var out: Array[Button] = []
	for row: Node in _list.get_children():
		if row is Button:
			out.append(row as Button)
	return out


func _source_of(pack: Dictionary) -> String:
	var path: String = str(pack.get("path", ""))
	return FileAccess.get_file_as_string(path) if not path.is_empty() else ""


## One row: the pack's icon, its name, what it is, and what else comes along. Clicking selects it and
## a double-click does what the window's button does.
func _build_row(pack: Dictionary) -> Button:
	var source: String = _source_of(pack)
	var row: Button = Button.new()
	row.toggle_mode = true
	row.clip_contents = true
	row.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(520.0), EventSheetPalette.scaled_f(74.0))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("pack_dir", str(pack.get("dir", "")))
	var pitch: String = str(pack.get("pitch", "")).strip_edges()
	row.tooltip_text = str(pack.get("name", "")) + (" - " + pitch if not pitch.is_empty() else "")
	row.pressed.connect(func() -> void: _select(str(pack.get("dir", ""))))
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.double_click and click.button_index == MOUSE_BUTTON_LEFT:
			_select(str(pack.get("dir", "")))
			_on_confirmed())
	var inset: MarginContainer = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		inset.add_theme_constant_override(side, int(EventSheetPalette.scaled_f(8.0)))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	inset.add_child(line)
	var icon: TextureRect = TextureRect.new()
	icon.texture = tile_icon(pack, source)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * EventSheetPalette.scaled_f(24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var on_kind: String = works_on(source)
	var kind_line: String = on_kind if not on_kind.is_empty() else EventSheetL10n.translate("Any node")
	var second: String = "%s · %s" % [kind_line, pitch] if not pitch.is_empty() else kind_line
	var said_lines: Array = [[str(pack.get("name", "")), EventSheetPopupUI.text_color(), 0],
		[second, EventSheetPopupUI.muted_text_color(), EventSheetPalette.scaled(11)]]
	if is_library_pack(pack):
		said_lines.append([needs_line(str(pack.get("dir", ""))), EventSheetPopupUI.muted_text_color(), EventSheetPalette.scaled(11)])
	for said: Array in said_lines:
		var label: Label = Label.new()
		label.text = str(said[0])
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", said[1])
		if int(said[2]) > 0:
			label.add_theme_font_size_override("font_size", int(said[2]))
		words.add_child(label)
	row.add_child(inset)
	return row


## The kind of object a pack's script works on - its typed `host`, else what it says it requires -
## or "" when any node will do. A pack that is not a node at all (a data pack extending Resource) is
## named by what it extends.
static func works_on(source: String) -> String:
	var not_a_node: String = non_node_base(source)
	if not not_a_node.is_empty():
		return not_a_node
	var needs: String = EventSheetBehaviourAddonScaffold.host_class_of(source)
	return needs if not needs.is_empty() else EventSheetAddBehavior.requirement_in(source)


## The engine class a pack's script extends when that class is not a node (Resource, RefCounted), or
## "" for a node or a script class - a pack like that is read by a sheet, never added under a node.
static func non_node_base(source: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("(?m)^extends\\s+([A-Za-z_][A-Za-z0-9_]*)").search(source)
	if found == null:
		return ""
	var base: String = found.get_string(1)
	if not ClassDB.class_exists(base) or base == "Node" or ClassDB.is_parent_class(base, "Node"):
		return ""
	return base


## A row's picture: the script's own @icon, else the pack's icon, else the editor icon of the kind
## of node it works on - what Godot's Scene dock would show for it.
static func tile_icon(pack: Dictionary, source: String) -> Texture2D:
	var drawn: RegExMatch = RegEx.create_from_string("(?m)^@icon\\(\"([^\"]+)\"\\)").search(source)
	var path: String = drawn.get_string(1) if drawn != null else str(pack.get("icon", ""))
	# Through the picker's own cache: loading every pack's picture costs about half a second the
	# first time, and the window is opened again and again while a scene is put together.
	# A pack the project does not hold yet names a picture under eventsheet_addons/; it is in the library.
	# Godot never imports that folder, so its picture is drawn from the file itself.
	if not path.is_empty() and not FileAccess.file_exists(path) and path.begins_with(EventSheetPackLibrary.PROJECT_ROOT):
		var library_picture: Texture2D = _svg_from_file(EventSheetPackLibrary.LIBRARY_ROOT.path_join(
			path.trim_prefix(EventSheetPackLibrary.PROJECT_ROOT).trim_prefix("/")))
		if library_picture != null:
			return library_picture
	var drawn_icon: Texture2D = EventSheetACEIcons.path_icon(path)
	if drawn_icon != null:
		return drawn_icon
	var kind: String = works_on(source)
	return EventSheetPopupUI._editor_icon(kind if not kind.is_empty() else "Node")


## The pictures drawn from library files, by path.
static var _svg_cache: Dictionary = {}


## A texture drawn from an .svg file Godot has not imported, or null when there is none to draw.
static func _svg_from_file(path: String) -> Texture2D:
	if _svg_cache.has(path):
		return _svg_cache[path] as Texture2D
	var drawn: Texture2D = null
	if path.get_extension() == "svg" and FileAccess.file_exists(path):
		var image: Image = Image.new()
		if image.load_svg_from_string(FileAccess.get_file_as_string(path), 1.5) == OK:
			drawn = ImageTexture.create_from_image(image)
	_svg_cache[path] = drawn
	return drawn


## What else a library pack brings, as one line: "Also adds Canvas Surface and Drawing Prefab
## Resource", or "Nothing else comes with it." Names, not folders - this is what a person reads.
static func needs_line(pack_dir: String, root: String = EventSheetPackLibrary.LIBRARY_ROOT,
		project_root: String = EventSheetPackLibrary.PROJECT_ROOT) -> String:
	var names: PackedStringArray = PackedStringArray()
	for folder: String in EventSheetPackLibrary.needs(pack_dir, root):
		if EventSheetPackLibrary.in_project(folder, project_root):
			continue
		names.append(str(EventSheetPackCatalog.describe(folder, root).get("name", folder)))
	if names.is_empty():
		return EventSheetL10n.translate("Nothing else comes with it.")
	return EventSheetL10n.translate("Also adds %s.") % EventSheetBehaviourLibraryFlow._and_list(names)


## The folders a library pack brings along, one per line, or a word saying it needs none.
static func library_needs_text(pack_dir: String, root: String = EventSheetPackLibrary.LIBRARY_ROOT,
		project_root: String = EventSheetPackLibrary.PROJECT_ROOT) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for folder: String in EventSheetPackLibrary.needs(pack_dir, root):
		var line: String = "%s/" % folder
		if EventSheetPackLibrary.in_project(folder, project_root):
			line += "  " + EventSheetL10n.translate("(already in the project)")
		lines.append(line)
	return "\n".join(lines) if not lines.is_empty() else EventSheetL10n.translate("Nothing else.")


## The Manual page a pack's "Read the guide" opens: the guide that ships with the plugin for it, else
## the pack's own guide when the project holds it, or "" when it has none. A library pack is not in
## the project, so its shipped guide is the only page it can have.
static func guide_doc_id(pack: Dictionary) -> String:
	var pack_dir: String = str(pack.get("dir", "")).strip_edges()
	if pack_dir.is_empty():
		return ""
	var shipped: String = "Addons/%s" % EventSheets.addon_guide_name(pack_dir)
	if EventSheetDocLibrary.has_page(shipped):
		return "guide:%s" % shipped
	if not is_library_pack(pack) and EventSheetDocExplain.opens_inside("addon:%s" % pack_dir):
		return "addon:%s" % pack_dir
	return ""


## Read the guide: the selected pack's guide, in the Manual. The window stays open behind it, since
## reading is how the choice gets made.
func _read_selected_guide() -> void:
	var guide: String = guide_doc_id(selected_pack())
	if not guide.is_empty():
		EventSheets.open_docs(guide)


func _select(pack_dir: String) -> void:
	_selected_dir = pack_dir
	for row: Button in rows():
		row.set_pressed_no_signal(str(row.get_meta("pack_dir", "")) == _selected_dir)
	var pack: Dictionary = selected_pack()
	var guide: String = guide_doc_id(pack) if not pack.is_empty() else ""
	if _guide_link != null:
		_guide_link.visible = not guide.is_empty()
		_guide_link.text = "%s · %s" % [str(pack.get("name", "")), EventSheetL10n.translate("Read the guide")]
	if not _adding:
		ok_button_text = EventSheetL10n.translate("Add to project") if _waiting_scope() else EventSheetL10n.translate("Remove from project…")
		get_ok_button().disabled = pack.is_empty()


## The pack the window is on, or an empty Dictionary. Public so the dock (and a test) can ask.
func selected_pack() -> Dictionary:
	for pack: Dictionary in _scoped_packs():
		if str(pack.get("dir", "")) == _selected_dir:
			return pack
	return {}


func _on_confirmed() -> void:
	var pack: Dictionary = selected_pack()
	if pack.is_empty():
		return
	if not _waiting_scope():
		if _on_remove.is_valid():
			_on_remove.call(pack)
		return
	_add_from_library(pack)


## Add to project: the window stays open while the folders are copied and imported, then says what
## came in and how to add it to a node, and the list drops the pack.
func _add_from_library(pack: Dictionary) -> void:
	if _adding or not _on_add.is_valid():
		return
	_adding = true
	get_ok_button().disabled = true
	ok_button_text = EventSheetL10n.translate("Adding…")
	var result: Dictionary = await _on_add.call(pack)
	_adding = false
	_selected_dir = ""
	_load_packs()
	_rebuild_list()
	if bool(result.get("ok", false)):
		_said_band.text = "✓ %s\n%s" % [str(result.get("message", "")), added_next_step()]
	else:
		_said_band.text = ""


## The one line said after a behaviour is added to the project: where it goes from here.
static func added_next_step() -> String:
	return EventSheetL10n.translate("Now add it with Add Child Node (Ctrl+A) under the node it should act on.")
