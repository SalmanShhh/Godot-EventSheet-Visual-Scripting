# Godot EventSheets - lets go of everything an extension registered, just before the process ends.
#
# The registries are static, and a registration is often a lambda: a Callable that keeps the script
# it was written in. A headless script that registered one and then quit reached the engine's
# shutdown with the registry still holding it, after the script's own class had been taken apart,
# and the process ended in a segfault (exit 139) whatever exit code the script asked for. So the
# first time the API is used, this file asks to be run when the scene tree is leaving, and then
# empties every registry that holds a Callable.
#
# DELIBERATELY NO `class_name`, and it names nothing: it is reached by path from the API's static
# initialiser, so loading the API pays a parse of these few lines and nothing more.
@tool
extends RefCounted

const THIS_FILE := "res://addons/eventsheet/api/registry_release.gd"
const API_FILE := "res://addons/eventsheet/api/eventsheets.gd"

static var _armed: bool = false
static var _waited: bool = false


## Asks for `release` to run when the scene tree is leaving. A script's own `_init` runs before the
## engine has a main loop, so with none yet the question is asked once more after it exists.
static func arm() -> void:
	if _armed:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		if not _waited:
			_waited = true
			Callable(load(THIS_FILE), "arm").call_deferred()
		return
	_armed = true
	tree.root.tree_exiting.connect(Callable(load(THIS_FILE), "release"))


## Empties every registry that can hold a Callable.
static func release() -> void:
	load(API_FILE).call("_release_registrations")
