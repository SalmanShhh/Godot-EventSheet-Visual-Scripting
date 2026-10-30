@tool
class_name EventSheetUndoRedoAdapter
extends RefCounted

var _manager: Variant = null
## The editor menu that carries Undo and Redo, once found: looking through the editor's every
## PopupMenu on each Ctrl+Z is the one cost this door has, and the menu lives as long as the editor.
static var _editor_menu: WeakRef = null
## The object whose edits these are (the dock). Inside the editor it names the history every step
## goes into, so asking "is there anything to undo" reads the same history the steps were put in.
var _context: Object = null


func set_manager(manager: Variant) -> void:
	_manager = manager


func set_context(context: Object) -> void:
	_context = context


func get_manager() -> Variant:
	return _manager


func has_manager() -> bool:
	return _manager != null


## Inside the editor the step is pinned to the context's history, the one has_undo and undo read.
func create_action(action_name: String) -> void:
	if _is_editor_manager() and _context != null:
		_call("create_action", [action_name, UndoRedo.MERGE_DISABLE, _context], false)
		return
	_call("create_action", [action_name], false)


func add_do_method(target: Object, method_name: String, args: Array = []) -> void:
	_call("add_do_method", _method_payload(target, method_name, args), false)


func add_undo_method(target: Object, method_name: String, args: Array = []) -> void:
	_call("add_undo_method", _method_payload(target, method_name, args), false)


## The editor's EditorUndoRedoManager takes (object, method, args...), but the plain UndoRedo the
## dock falls back to with no editor around (tests, preview harnesses) takes ONE Callable. Handing it
## the editor's spelling printed "expected 1 argument(s), but called with 3" on every edit and
## recorded nothing, so a fallback edit could not be undone.
func _method_payload(target: Object, method_name: String, args: Array) -> Array:
	if _manager is UndoRedo:
		return [Callable(target, method_name).bindv(args)]
	var payload: Array = [target, method_name]
	payload.append_array(args)
	return payload


## The plain UndoRedo records the step WITHOUT running it: every caller has already applied its edit,
## and with no editor around the step never ran at commit before either (its methods were refused),
## so the fallback keeps what it did and gains a history that undo and redo can walk.
func commit_action() -> void:
	_call("commit_action", [false] if _manager is UndoRedo else [], false)


## The editor's EditorUndoRedoManager has no has_undo, has_redo, undo or redo of its own: those live on
## the plain UndoRedo of each history it keeps. Asking the manager itself answered "nothing to undo"
## for every step, so the dock's Undo button, its Ctrl+Z and the History panel all did nothing in the
## editor while every test (which runs on a plain UndoRedo) passed. Inside the editor the answer is the
## editor's own - whether its Undo (Redo) item is live - because that is the step undo() takes.
func has_undo() -> bool:
	if _is_editor_manager():
		var live: int = editor_command_state("ui_undo")
		if live >= 0:
			return live == 1
	return bool(_history_call("has_undo", false))


func has_redo() -> bool:
	if _is_editor_manager():
		var live: int = editor_command_state("ui_redo")
		if live >= 0:
			return live == 1
	return bool(_history_call("has_redo", false))


## Inside the editor a step is taken back through the editor's own Undo - Scene > Undo, the item found
## by the editor's own shortcut - so EditorUndoRedoManager moves the step between its stacks, emits
## history_changed and the History panel follows. Running the history's UndoRedo by hand skipped all
## of that: the manager still offered the step, so a later Scene > Undo took one step too many, and
## Scene > Redo had nothing to redo. Like Scene > Undo, it takes back the editor's newest step, which
## is the sheet's own unless a scene was edited since. Only with no such menu item (no editor, a
## stand-in) is the history asked directly.
func undo() -> void:
	if _is_editor_manager() and run_editor_command("ui_undo"):
		return
	_history_call("undo")


func redo() -> void:
	if _is_editor_manager() and run_editor_command("ui_redo"):
		return
	_history_call("redo")


## Activates the editor menu item that carries one of the editor's own shortcuts (ui_undo, ui_redo),
## through the PopupMenu itself, exactly as choosing it would. Returns false when there is no editor,
## no such shortcut, or no menu item carrying it. An item the editor has greyed out is the editor
## saying there is no step: nothing runs, and the history is not asked behind its back.
static func run_editor_command(shortcut_path: String) -> bool:
	var item: Array = _editor_command_item(shortcut_path)
	if item.is_empty():
		return false
	var menu: PopupMenu = item[0] as PopupMenu
	var index: int = int(item[1])
	if menu.is_item_disabled(index):
		return true
	menu.id_pressed.emit(menu.get_item_id(index))
	return true


## 1 when the editor's menu item for that shortcut is live, 0 when the editor has greyed it out, -1
## when there is no such item to ask (no editor, a stand-in).
static func editor_command_state(shortcut_path: String) -> int:
	var item: Array = _editor_command_item(shortcut_path)
	if item.is_empty():
		return -1
	return 0 if (item[0] as PopupMenu).is_item_disabled(int(item[1])) else 1


static func _editor_command_item(shortcut_path: String) -> Array:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return []
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null or not settings.has_shortcut(shortcut_path):
		return []
	var shortcut: Shortcut = settings.get_shortcut(shortcut_path)
	var item: Array = []
	var cached: PopupMenu = _editor_menu.get_ref() as PopupMenu if _editor_menu != null else null
	if cached != null:
		item = editor_menu_item(cached, shortcut, true)
	if item.is_empty():
		item = editor_menu_item(EditorInterface.get_base_control(), shortcut)
	if not item.is_empty():
		_editor_menu = weakref(item[0])
	return item


## [menu, index] of the first PopupMenu item under `root` that carries `shortcut`, or [] for none;
## with `only_root`, `root` is the menu and nothing under it is searched. Pure over the tree it is
## handed, so a test can build the menu it looks through.
static func editor_menu_item(root: Node, shortcut: Shortcut, only_root: bool = false) -> Array:
	if root == null or shortcut == null:
		return []
	var menus: Array = [root]
	if not only_root:
		menus = root.find_children("*", "PopupMenu", true, false)
	for node: Node in menus:
		var menu: PopupMenu = node as PopupMenu
		if menu == null:
			continue
		for index: int in range(menu.item_count):
			if menu.get_item_shortcut(index) == shortcut:
				return [menu, index]
	return []


## Inside the editor only the dock's own history is cleared. The manager's clear_history() with no
## history named clears EVERY history, the open scenes' included.
func clear_history() -> void:
	if _is_editor_manager():
		_call("clear_history", [_history_id()])
		return
	_call("clear_history")


func _is_editor_manager() -> bool:
	return _manager != null and _manager.has_method("get_history_undo_redo") \
		and _manager.has_method("get_object_history_id")


func _history_id() -> int:
	return int(_manager.call("get_object_history_id", _context)) if _context != null else 0


func _history_call(method: String, fallback: Variant = null) -> Variant:
	if not _is_editor_manager():
		return _call(method, [], fallback)
	var history: Object = _manager.call("get_history_undo_redo", _history_id())
	if history == null or not history.has_method(method):
		return fallback
	return history.call(method)


func _call(method: String, args: Array = [], fallback: Variant = null) -> Variant:
	if _manager == null:
		return fallback
	if not _manager.has_method(method):
		return fallback
	return _manager.callv(method, args)
