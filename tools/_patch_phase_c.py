import io

# ── 1. Dock: Export as Addon Pack ──
p = "addons/eventsheet/editor/event_sheet_dock.gd"
s = io.open(p, encoding="utf-8").read()
old = '    _add_toolbar_button("Save As", _on_save_as_requested)'
assert old in s
s = s.replace(old, old + '\n    _add_toolbar_button("Export Addon…", _export_addon_pack)', 1)

anchor = '# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─'
idx = s.index(anchor)
block = '''# ── Export as Addon Pack (C3 coverage Phase C) ────────────────────────────────────────

## One-click addon publishing: writes the current behavior sheet (+ compiled script) into
## eventsheet_addons/<class_snake>/ where the zero-config scanner publishes its ACEs
## project-wide — the same layout the bundled packs use. base_dir_override is for tests.
func _export_addon_pack(base_dir_override: String = "") -> void:
    if _current_sheet == null:
        return
    if not _current_sheet.behavior_mode or _current_sheet.custom_class_name.strip_edges().is_empty():
        _set_status("Addon packs are behavior sheets — enable behavior mode and set a class name first (Sheet Type).", true)
        return
    var class_name_text: String = _current_sheet.custom_class_name.strip_edges()
    if not EventSheetIdentifierRules.is_valid(class_name_text):
        _set_status("\\"%s\\" can't be a class name (letters/digits/underscores, not a keyword)." % class_name_text, true)
        return
    var folder_name: String = class_name_text.to_snake_case()
    var base_dir: String = base_dir_override if not base_dir_override.is_empty() else "res://eventsheet_addons/%s" % folder_name
    var base_path: String = "%s/%s" % [base_dir, folder_name]
    DirAccess.make_dir_recursive_absolute(base_dir)
    var pack_sheet: EventSheetResource = _current_sheet.duplicate(true)
    var save_error: Error = ResourceSaver.save(pack_sheet, base_path + ".tres")
    if save_error != OK:
        _set_status("Export failed: couldn't save %s.tres (error %d)." % [base_path, save_error], true)
        return
    # Adopt the saved path BEFORE compiling so the generated "# Source:" header matches a
    # recompile of the exported .tres (the same no-drift rule the bundled packs follow).
    pack_sheet.take_over_path(base_path + ".tres")
    var compile_result: Dictionary = SheetCompiler.compile(pack_sheet, base_path + ".gd")
    if not bool(compile_result.get("success", false)):
        _set_status("Export failed: the sheet doesn't compile (%s)." % str(compile_result.get("errors")), true)
        return
    if Engine.is_editor_hint() and is_inside_tree():
        EditorInterface.get_resource_filesystem().scan()
    _set_status("Exported addon pack to %s (.tres + .gd) — its ACEs are now published project-wide." % base_dir)

''' + anchor
s = s[:idx] + block + s[idx:]
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("export done")

# ── 2. Params dialog: drag-from-docks into fx fields ──
p = "addons/eventsheet/editor/ace_params_dialog.gd"
s = io.open(p, encoding="utf-8").read()
old = """	edit.text_changed.connect(func() -> void:"""
assert old in s
s = s.replace(old, """	# Godot-native drag & drop: dropping a FileSystem file inserts its quoted res:// path,
	# dropping a Scene-dock node inserts a $Path reference.
	edit.set_drag_forwarding(Callable(), _can_drop_on_expression, _drop_on_expression.bind(edit))
	edit.text_changed.connect(func() -> void:""", 1)
old = "static func color_to_literal(value: Color) -> String:"
assert old in s
s = s.replace(old, """func _can_drop_on_expression(_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var kind: String = str((data as Dictionary).get("type", ""))
	return kind == "files" or kind == "nodes"

func _drop_on_expression(_position: Vector2, data: Variant, edit: CodeEdit) -> void:
	var snippet: String = drop_data_to_expression(data)
	if not snippet.is_empty():
		edit.insert_text_at_caret(snippet)

## Converts an editor drag payload to GDScript: FileSystem files become quoted res://
## paths; Scene-dock nodes become $Path references (relative to the edited scene root).
static func drop_data_to_expression(data: Variant) -> String:
	if not (data is Dictionary):
		return ""
	var payload: Dictionary = data as Dictionary
	match str(payload.get("type", "")):
		"files":
			var files: Array = payload.get("files", [])
			return "\\"%s\\"" % str(files[0]) if not files.is_empty() else ""
		"nodes":
			var nodes: Array = payload.get("nodes", [])
			if nodes.is_empty():
				return ""
			var node_path: String = str(nodes[0])
			var relative: String = node_path.get_file()
			if Engine.is_editor_hint():
				var scene_root: Node = EditorInterface.get_edited_scene_root()
				if scene_root != null:
					var root_prefix: String = str(scene_root.get_path())
					if node_path.begins_with(root_prefix + "/"):
						relative = node_path.trim_prefix(root_prefix + "/")
			return _node_reference(relative)
	return ""

## $Name for identifier-safe paths, $"Path/To Node" otherwise.
static func _node_reference(relative_path: String) -> String:
	var identifier_regex: RegEx = RegEx.new()
	if identifier_regex.compile("^[A-Za-z_][A-Za-z0-9_]*$") == OK and identifier_regex.search(relative_path) != null:
		return "$%s" % relative_path
	return "$\\"%s\\"" % relative_path

static func color_to_literal(value: Color) -> String:""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("drop done")

# ── 3. Lint: scene-tree-aware $-completion ──
p = "addons/eventsheet/ace/gdscript_lint.gd"
s = io.open(p, encoding="utf-8").read()
old = '''class_name EventSheetGDScriptLint
extends RefCounted'''
assert old in s
s = s.replace(old, '''class_name EventSheetGDScriptLint
extends RefCounted

## Override for tests / non-editor hosts: a Callable returning the scene root used for
## $Node completion. Defaults to the editor's edited scene when inside the editor.
static var scene_root_provider: Callable = Callable()''', 1)
old = """					_add_class_members(candidates, seen, script.get_instance_base_type())
		return candidates"""
assert old in s
s = s.replace(old, """					_add_class_members(candidates, seen, script.get_instance_base_type())
		# Not a registered class: try the OPEN SCENE's actual nodes ($Child completes its
		# script members, signals and class members — Godot-native muscle memory).
		if candidates.is_empty():
			var scene_root: Node = _resolve_scene_root()
			if scene_root != null:
				var child: Node = scene_root.get_node_or_null(NodePath(token.substr(1)))
				if child != null:
					var child_script: Script = child.get_script() as Script
					if child_script != null:
						for method_info in child_script.get_script_method_list():
							var script_method: String = str(method_info.get("name", ""))
							if not script_method.is_empty() and not script_method.begins_with("_"):
								_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, script_method)
						for signal_info in child_script.get_script_signal_list():
							_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, str(signal_info.get("name", "")))
					_add_class_members(candidates, seen, child.get_class())
		return candidates""", 1)
old = """	for enum_row in _sheet_enums(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_CLASS, enum_row.enum_name)"""
assert old in s
s = s.replace(old, old + """
	# Direct children of the open scene complete as $Name references.
	var scene_root: Node = _resolve_scene_root()
	if scene_root != null:
		for child in scene_root.get_children():
			_add_candidate(candidates, seen, CodeEdit.KIND_NODE_PATH, "$%s" % child.name)""", 1)
old = "## Path of a registered global script class (class_name), \"\" when unknown."
assert old in s
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
