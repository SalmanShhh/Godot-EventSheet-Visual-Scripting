# Godot EventSheets - where the open workspace is announced, and the lists it writes to and reads
# while it is being built and opening its first sheet: the Command Palette's extension commands,
# the row menu's extension items and the sheet lifecycle listeners.
#
# `EventSheets` is the public API, and between them its methods name the compiler, the importer,
# the Doctor, the viewport and the pickers, so naming that one class compiles all of it. The
# workspace announces itself and registers its own palette commands and row items while it is
# CONSTRUCTED, and fires the lifecycle listeners from the sheet open that follows - both part of the
# first open of a sheet - so doing that through the API put the whole API subtree into the first
# open, and made every file the API names wait on the workspace in turn.
#
# So the STORAGE lives here, in a file that names nothing at all, and `EventSheets` forwards to it.
# The public method shapes on the API are unchanged - they are a frozen contract - and an extension
# keeps registering through `EventSheets` exactly as before. Only the workspace itself, which is
# being built or opening a sheet at the moment it reaches these lists, uses this file directly.
#
# DELIBERATELY NO `class_name`, for the same reason as the extension registries beside it: there is
# nothing here worth naming, and a file reached by path pays a parse of these few lines instead of a
# compile of the plugin.
@tool
extends RefCounted

## The editor project-metadata section and key that record "this project has been welcomed". The
## Welcome window writes it, and the workspace reads it on every first open to decide whether to
## build that window at all - so it lives here, where reading it compiles nothing.
const WELCOMED_METADATA: Array[String] = ["eventsheets", "welcomed"]

## The live workspace, announced by the workspace itself while it is built. Weak by contract: every
## reader checks validity, so a closed workspace never leaves the API pointing at a freed node.
static var _dock: Control = null
## Palette entries registered from code: Array of {"title": String, "run": Callable}. Each one is
## also put on Godot's own Command Palette (Ctrl+Shift+P) as it is registered.
static var _palette_commands: Array[Dictionary] = []
## Where an entry goes to reach Godot's own Command Palette: called as forwarder.call(adding, display
## title, key, action). Empty in the editor, where the registry talks to the palette itself; the suite
## sets it so a test needs no editor.
static var forwarder: Callable = Callable()
## The keys this registry has put on Godot's Command Palette, so it removes only what it added.
static var _on_godot_palette: Dictionary = {}
## Row context-menu items: [{label, filter: Callable(resource)->bool, action: Callable(resource)}].
static var _row_menu_items: Array[Dictionary] = []
## Lifecycle listeners: event name -> Array[Callable]. The workspace fires these from its own open,
## save and compile funnels - the first of which runs while the first sheet is being opened.
static var _lifecycle: Dictionary = {"opened": [], "saved": [], "compiled": []}
## The dictionary-defined verbs (`EventSheets.register_simple_ace`). The API owns the typed list and
## hands this file the SAME array object the moment it registers one, so a verb registered, or the
## list cleared, through the API is what the workspace's vocabulary reads on its next refresh - the
## first of which runs while the workspace is being built. Empty until something registers.
static var _simple_aces: Array = []


static func register_dock(dock: Control) -> void:
	_dock = dock


static func dock() -> Control:
	return _dock


static func dock_alive() -> bool:
	return _dock != null and is_instance_valid(_dock)


## An optional category prefixes the display title ("My Pack: Reroll Loot") so extension commands
## group together in Godot's Command Palette. Re-registering a title replaces it.
static func register_palette_command(title: String, action: Callable, category: String = "") -> void:
	if not category.is_empty():
		title = "%s: %s" % [category, title]
	unregister_palette_command(title)
	_palette_commands.append({"title": title, "run": action})
	_forward(true, title, action)


static func unregister_palette_command(title: String) -> void:
	for index: int in range(_palette_commands.size() - 1, -1, -1):
		if str(_palette_commands[index].get("title", "")) == title:
			_palette_commands.remove_at(index)
			_forward(false, title, Callable())


## The key an entry has in Godot's palette: "eventsheets/" and the title in lower-case words joined
## by underscores, so Godot files every entry under one "Eventsheets" heading.
static func godot_palette_key(title: String) -> String:
	var slug: String = ""
	for character: String in title.to_lower():
		slug += character if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") else "_"
	while slug.contains("__"):
		slug = slug.replace("__", "_")
	return "eventsheets/" + slug.trim_prefix("_").trim_suffix("_")


## The words Godot's palette shows for an entry: the plugin's name in front of a title with no
## category of its own, so a reader typing "EventSheets" finds every one.
static func godot_palette_title(title: String) -> String:
	return title if title.contains(": ") else "EventSheets: " + title


## Adds or takes back one entry on Godot's own Command Palette. Outside the editor there is none, and
## a palette that is not built yet is skipped without a word: the entry stays in the registry.
static func _forward(adding: bool, title: String, action: Callable) -> void:
	var key: String = godot_palette_key(title)
	if forwarder.is_valid():
		forwarder.call(adding, godot_palette_title(title), key, action)
		return
	if not Engine.is_editor_hint():
		return
	var palette: Object = EditorInterface.get_command_palette()
	if palette == null:
		return
	# Godot reports an error for a key that is not there (to remove) or already there (to add), so this
	# keeps its own list of what it put on the palette.
	if _on_godot_palette.has(key):
		palette.call("remove_command", key)
		_on_godot_palette.erase(key)
	if adding:
		palette.call("add_command", godot_palette_title(title), key, action)
		_on_godot_palette[key] = true


## The registered extension commands, in registration order.
static func palette_commands() -> Array[Dictionary]:
	return _palette_commands.duplicate()


## Re-registering a label replaces it.
static func register_row_menu_item(label: String, filter: Callable, action: Callable) -> void:
	unregister_row_menu_item(label)
	_row_menu_items.append({"label": label, "filter": filter, "action": action})


static func unregister_row_menu_item(label: String) -> void:
	for index: int in range(_row_menu_items.size() - 1, -1, -1):
		if str(_row_menu_items[index].get("label", "")) == label:
			_row_menu_items.remove_at(index)


## The registered row items whose filter accepts `resource` (no filter accepts every row).
static func row_menu_items_for(resource: Resource) -> Array[Dictionary]:
	var applicable: Array[Dictionary] = []
	for entry: Dictionary in _row_menu_items:
		var filter: Callable = entry.get("filter", Callable())
		if not filter.is_valid() or bool(filter.call(resource)):
			applicable.append(entry)
	return applicable


## Called by the API with its own list of simple verbs; held by reference, never copied.
static func share_simple_aces(definitions: Array) -> void:
	_simple_aces = definitions


## The simple verbs, for the vocabulary refresh. The API's own array once one is registered.
static func simple_aces() -> Array:
	return _simple_aces


## Adds a listener for "opened", "saved" or "compiled".
static func on_lifecycle(event_name: String, callback: Callable) -> void:
	(_lifecycle[event_name] as Array).append(callback)


## Runs every listener for `event_name` with `payload`, skipping any whose object has gone.
static func notify_lifecycle(event_name: String, payload: Dictionary) -> void:
	for callback: Callable in (_lifecycle.get(event_name, []) as Array):
		if callback.is_valid():
			callback.call(payload)


## Takes back everything `dock` registered, as it is freed: the announcement, if it is still the one
## announced, and every palette command and row item whose callable belongs to it. Entries another
## workspace has since registered under the same title are left alone. A callable whose object is
## gone can only fail when picked - and one still held here when the engine shuts down outlives the
## script its function lives in, which takes the process down on the way out.
static func forget(dock: Control) -> void:
	if _dock == dock:
		_dock = null
	for index: int in range(_palette_commands.size() - 1, -1, -1):
		# A command made by one of the dock's own helpers (the menu bar's) belongs to it all the same.
		var owner: Object = (_palette_commands[index].get("run", Callable()) as Callable).get_object()
		if owner == dock or (owner != null and owner.get("_dock") == dock):
			_forward(false, str(_palette_commands[index].get("title", "")), Callable())
			_palette_commands.remove_at(index)
	for index: int in range(_row_menu_items.size() - 1, -1, -1):
		var entry: Dictionary = _row_menu_items[index]
		if (entry.get("filter", Callable()) as Callable).get_object() == dock \
				or (entry.get("action", Callable()) as Callable).get_object() == dock:
			_row_menu_items.remove_at(index)
