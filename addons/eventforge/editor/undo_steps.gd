# Godot EventSheets - one Godot undo step for the scene and settings edits the plugin makes
#
# A node attached, a script set, a node moved under another, an Input Map action added: each is a
# change to the scene or to project.godot, and Ctrl+Z in Godot's own editor should take it back. Each
# function here opens ONE named step on the editor's undo manager (EditorInterface's), does the change
# as the step's do half and records its opposite as the undo half; committing the step performs it.
#
# With no editor around (the test suite, a preview harness) the same step is recorded on a plain
# UndoRedo the caller hands in as `undo`, which records without running, so the change is made here
# directly. Nothing about the change differs between the two - only who ran it.
#
# Loaded by path from the doors that use it; it has no class_name, so nothing that names it compiles it.
@tool
extends RefCounted


## The manager a step goes on: the one a caller handed in, else the editor's own, else none.
static func manager_for(undo: Object) -> Object:
	if undo != null:
		return undo
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return (Engine.get_singleton("EditorInterface") as Object).call("get_editor_undo_redo")
	return null


## Adds `child` under `host`, owned by `scene_owner` so the scene saves it. Ctrl+Z removes it again.
static func add_child_step(host: Node, child: Node, scene_owner: Node, label: String, undo: Object = null) -> void:
	var manager: Object = manager_for(undo)
	if manager == null:
		_add_child(host, child, scene_owner)
		return
	manager.call("create_action", label)
	_do(manager, host, "add_child", [child, true])
	_do(manager, child, "set_owner", [scene_owner])
	_undo(manager, host, "remove_child", [child])
	manager.call("add_do_reference", child)
	_commit(manager, func() -> void: _add_child(host, child, scene_owner))


## Moves `node` under `new_parent`, at the end, owned by `scene_owner`. Ctrl+Z puts it back at the
## place it came from.
static func reparent_step(node: Node, new_parent: Node, scene_owner: Node, label: String, undo: Object = null) -> void:
	var old_parent: Node = node.get_parent()
	var old_index: int = node.get_index()
	var manager: Object = manager_for(undo)
	if manager == null:
		_move(node, old_parent, new_parent, scene_owner, -1)
		return
	manager.call("create_action", label)
	_do(manager, old_parent, "remove_child", [node])
	_do(manager, new_parent, "add_child", [node, true])
	_do(manager, node, "set_owner", [scene_owner])
	_undo(manager, new_parent, "remove_child", [node])
	_undo(manager, old_parent, "add_child", [node, true])
	_undo(manager, old_parent, "move_child", [node, old_index])
	_undo(manager, node, "set_owner", [scene_owner])
	_commit(manager, func() -> void: _move(node, old_parent, new_parent, scene_owner, -1))


## Sets a property on an object as one step: a node's script, a resource slot. Ctrl+Z sets it back.
static func set_property_step(target: Object, property: String, value: Variant, label: String, undo: Object = null) -> void:
	var before: Variant = target.get(property)
	var manager: Object = manager_for(undo)
	if manager == null:
		target.set(property, value)
		return
	manager.call("create_action", label)
	manager.call("add_do_property", target, property, value)
	manager.call("add_undo_property", target, property, before)
	_commit(manager, func() -> void: target.set(property, value))


## Writes one project setting as a step, saving project.godot on the way in and on the way out. Ctrl+Z
## clears it again. `save` is false only where a caller must not touch the project file (the suite).
static func project_setting_step(key: String, value: Variant, label: String, save: bool = true, undo: Object = null) -> void:
	var before: Variant = ProjectSettings.get_setting(key, null) if ProjectSettings.has_setting(key) else null
	var manager: Object = manager_for(undo)
	if manager == null:
		_write_setting(key, value, save)
		return
	manager.call("create_action", label)
	_do(manager, ProjectSettings, "set_setting", [key, value])
	_undo(manager, ProjectSettings, "set_setting", [key, before])
	if save and Engine.is_editor_hint():
		_do(manager, ProjectSettings, "save", [])
		_undo(manager, ProjectSettings, "save", [])
	_commit(manager, func() -> void: _write_setting(key, value, save))


static func _write_setting(key: String, value: Variant, save: bool) -> void:
	ProjectSettings.set_setting(key, value)
	if save and Engine.is_editor_hint():
		ProjectSettings.save()


static func _add_child(host: Node, child: Node, scene_owner: Node) -> void:
	host.add_child(child, true)
	child.owner = scene_owner


static func _move(node: Node, old_parent: Node, new_parent: Node, scene_owner: Node, _index: int) -> void:
	old_parent.remove_child(node)
	new_parent.add_child(node, true)
	node.owner = scene_owner


## The editor's manager takes (object, method, args...); a plain UndoRedo takes one Callable.
static func _do(manager: Object, target: Object, method: String, args: Array) -> void:
	if manager is UndoRedo:
		manager.call("add_do_method", Callable(target, method).bindv(args))
	else:
		manager.callv("add_do_method", [target, method] + args)


static func _undo(manager: Object, target: Object, method: String, args: Array) -> void:
	if manager is UndoRedo:
		manager.call("add_undo_method", Callable(target, method).bindv(args))
	else:
		manager.callv("add_undo_method", [target, method] + args)


## Committing performs the step on the editor's manager; a plain UndoRedo only records it, so the
## change is made by hand.
static func _commit(manager: Object, apply: Callable) -> void:
	if manager is UndoRedo:
		manager.call("commit_action", false)
		apply.call()
	else:
		manager.call("commit_action")
