import io

T = "\t"
p = "addons/eventsheet/ace/gdscript_lint.gd"
s = io.open(p, encoding="utf-8").read()

old = "class_name EventSheetGDScriptLint\nextends RefCounted"
assert old in s, "header"
s = s.replace(old, old + """

## Override for tests / non-editor hosts: a Callable returning the scene root used for
## $Node completion. Defaults to the editor's edited scene when inside the editor.
static var scene_root_provider: Callable = Callable()""", 1)

old = T*5 + "_add_class_members(candidates, seen, script.get_instance_base_type())\n" + T*2 + "return candidates"
assert old in s, "dollar branch"
new = (T*5 + "_add_class_members(candidates, seen, script.get_instance_base_type())\n"
+ T*2 + "# Not a registered class: try the OPEN SCENE's actual nodes ($Child completes its\n"
+ T*2 + "# script members, signals and class members — Godot-native muscle memory).\n"
+ T*2 + "if candidates.is_empty():\n"
+ T*3 + "var scene_root: Node = _resolve_scene_root()\n"
+ T*3 + "if scene_root != null:\n"
+ T*4 + "var child: Node = scene_root.get_node_or_null(NodePath(token.substr(1)))\n"
+ T*4 + "if child != null:\n"
+ T*5 + "var child_script: Script = child.get_script() as Script\n"
+ T*5 + "if child_script != null:\n"
+ T*6 + "for method_info in child_script.get_script_method_list():\n"
+ T*7 + "var script_method: String = str(method_info.get(\"name\", \"\"))\n"
+ T*7 + "if not script_method.is_empty() and not script_method.begins_with(\"_\"):\n"
+ T*8 + "_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, script_method)\n"
+ T*6 + "for signal_info in child_script.get_script_signal_list():\n"
+ T*7 + "_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, str(signal_info.get(\"name\", \"\")))\n"
+ T*5 + "_add_class_members(candidates, seen, child.get_class())\n"
+ T*2 + "return candidates")
s = s.replace(old, new, 1)

old = (T + "for enum_row in _sheet_enums(sheet):\n"
+ T*2 + "_add_candidate(candidates, seen, CodeEdit.KIND_CLASS, enum_row.enum_name)")
assert old in s, "flat anchor"
s = s.replace(old, old + "\n"
+ T + "# Direct children of the open scene complete as $Name references.\n"
+ T + "var scene_root: Node = _resolve_scene_root()\n"
+ T + "if scene_root != null:\n"
+ T*2 + "for child in scene_root.get_children():\n"
+ T*3 + "_add_candidate(candidates, seen, CodeEdit.KIND_NODE_PATH, \"$%s\" % child.name)", 1)

old = "## Path of a registered global script class (class_name), \"\" when unknown."
assert old in s, "helper anchor"
s = s.replace(old, """## The scene root for $-completion: the injected provider (tests), else the editor's
## edited scene, else null (headless/runtime).
static func _resolve_scene_root() -> Node:
	if scene_root_provider.is_valid():
		return scene_root_provider.call() as Node
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root()
	return null

## Path of a registered global script class (class_name), \"\" when unknown.""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("lint done")
