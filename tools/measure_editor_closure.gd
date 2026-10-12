# Measures what the first open of the workspace COMPILES, without compiling any of it. Run:
#   godot --headless --path . --script tools/measure_editor_closure.gd
#   godot --headless --path . --script tools/measure_editor_closure.gd -- root=res://path/to/file.gd
#
# WHY THIS EXISTS: the plugin builds its workspace editor lazily, by loading
# `addons/eventforge/editor/event_sheet_editor.gd` by path on the first open. In GDScript, a global
# class named anywhere in a file's CODE - a call on it, a var / param / return type, `is` / `as`, a
# const preload - compiles that class when the file loads, and that class's own names compile in
# turn. So the first open pays for the whole transitive set of files the editor names, which has
# grown to most of the plugin. The timing probe (`tests/cold_boot_probe.gd`) says how long that
# takes; this tool says WHICH files it is, and which single names hold the most of it in.
#
# THE WALK, EXACTLY. It is a static reading of the sources, so it compiles nothing and answers the
# same on every run:
#   - every `class_name` declared by a `.gd` under `res://addons/` is indexed against its file;
#   - each file is read with its comments and string literals blanked out, so a name in a comment,
#     in a docstring or in a `load("res://...")` path is not a reference - a by-path `load()` is
#     exactly the lazy door the plugin uses on purpose, and it compiles nothing up front;
#   - what IS followed: every indexed class name used as an identifier in the remaining code (not
#     after a `.`, which makes it a member, and not the file's own name), plus every
#     `preload("res://...gd")` and `extends "res://...gd"`, which are compile-time by definition;
#   - the closure is everything reachable from the root that way, the root included.
#
# WHAT IT PRINTS:
#   closure: N files, M lines            - the set the first open compiles
#   hubs                                 - per file in the closure, how much of the closure would
#                                          go if no file reached that one (its name gone from every
#                                          other file's code); the fifteen largest, which are the
#                                          cuts worth making first; the root's own base classes
#                                          are left out, since nothing loads the root without them
#   largest files                        - the fifteen biggest files in the closure
#
# A hub's figure is what removing that ONE door saves. Two doors into the same subtree each save
# nothing on their own, and the subtree only drops when both go - so a small figure on a big file
# means "it is reached some other way too", not "it is cheap".
extends SceneTree

const ADDONS_ROOT: String = "res://addons/"
const DEFAULT_ROOT: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
const LISTED: int = 15

## Comments and string literals, longest form first so a triple-quoted string is one match. The
## `&` / `^` / `r` prefixes of StringName, NodePath and raw strings sit outside the quote and are
## left behind as harmless identifier fragments.
const STRIP_PATTERN: String = "\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'|#[^\\n]*"

## The compile-time path references, read off the RAW source before anything is blanked. A match
## inside a comment is ruled out by testing it against the blanked text (see `_path_references`).
const PATH_PATTERN: String = "(?:preload\\s*\\(\\s*|^extends\\s+)\"(res://[^\"]+\\.gd)\""

const CLASS_NAME_PATTERN: String = "(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)"
const IDENTIFIER_PATTERN: String = "(?<![.\\w])[A-Za-z_][A-Za-z0-9_]*"


func _init() -> void:
	var root_path: String = DEFAULT_ROOT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("root="):
			root_path = argument.trim_prefix("root=")
	if not FileAccess.file_exists(root_path):
		push_error("[closure] no such file: %s" % root_path)
		quit(1)
		return
	var graph: Dictionary = build_graph(ADDONS_ROOT, root_path)
	var edges: Dictionary = graph["edges"]
	var lines: Dictionary = graph["lines"]
	var names: Dictionary = graph["names"]
	var closure: PackedStringArray = reach(edges, root_path, "")
	var total_lines: int = _sum_lines(closure, lines)
	print("closure: %d files, %d lines (root %s; %d class names indexed under %s)" % [
		closure.size(), total_lines, root_path, names.size(), ADDONS_ROOT])
	var chain: PackedStringArray = base_chain(graph, root_path)
	print("hubs (what goes from the closure if no file reaches it; not counting %s):" % ", ".join(PackedStringArray(
		Array(chain).map(func(path: String) -> String: return path.get_file()))))
	for hub: Dictionary in hubs(edges, lines, root_path, closure, chain):
		print("  %8d lines %4d files  %s" % [hub["lines"], hub["files"], _label(hub["path"], graph)])
	print("largest files:")
	var by_size: Array = Array(closure)
	by_size.sort_custom(func(a: String, b: String) -> bool:
		return lines[a] > lines[b] or (lines[a] == lines[b] and a < b))
	for path: Variant in by_size.slice(0, LISTED):
		print("  %8d lines  %s" % [lines[path], _label(str(path), graph)])
	quit(0)


## Every file the walk can see and what each one names: `edges` maps a path to the sorted paths it
## reaches at compile time, `lines` maps it to its line count, `names` maps a class name to its file
## and `named` maps a file back to its class name. Files outside `addons_root` that are reached by a
## preload path are read too, so a path reference never leads off the edge of the map.
static func build_graph(addons_root: String, root_path: String) -> Dictionary:
	var strip: RegEx = RegEx.create_from_string(STRIP_PATTERN)
	var class_line: RegEx = RegEx.create_from_string(CLASS_NAME_PATTERN)
	var identifier: RegEx = RegEx.create_from_string(IDENTIFIER_PATTERN)
	var path_reference: RegEx = RegEx.create_from_string("(?m)" + PATH_PATTERN)
	var sources: Dictionary = {}
	var names: Dictionary = {}
	var named: Dictionary = {}
	var pending: Array[String] = _scripts_under(addons_root)
	pending.append(root_path)
	var edges: Dictionary = {}
	var lines: Dictionary = {}
	var stripped: Dictionary = {}
	var bases: Dictionary = {}
	var base_line: RegEx = RegEx.create_from_string("(?m)^extends\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var base_path: RegEx = RegEx.create_from_string("(?m)^extends\\s+\"(res://[^\"]+\\.gd)\"")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if sources.has(path) or not FileAccess.file_exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		sources[path] = source
		lines[path] = source.count("\n") + (0 if source.ends_with("\n") or source.is_empty() else 1)
		stripped[path] = _blank(strip, source)
		if path.begins_with(addons_root):
			var declared: RegExMatch = class_line.search(stripped[path])
			if declared != null:
				names[declared.get_string(1)] = path
				named[path] = declared.get_string(1)
		for target: String in _path_references(path_reference, source, stripped[path]):
			pending.append(target)
	for path: String in sources:
		var reached: Dictionary = {}
		for target: String in _path_references(path_reference, sources[path], stripped[path]):
			if sources.has(target) and target != path:
				reached[target] = true
		for found: RegExMatch in identifier.search_all(stripped[path]):
			var target: Variant = names.get(found.get_string(), null)
			if target != null and target != path:
				reached[target] = true
		var sorted: PackedStringArray = PackedStringArray(reached.keys())
		sorted.sort()
		edges[path] = sorted
		var base: RegExMatch = base_line.search(stripped[path])
		if base != null:
			bases[path] = names.get(base.get_string(1), "")
		else:
			base = base_path.search(sources[path])
			if base != null and stripped[path].substr(base.get_start(), 7) == "extends":
				bases[path] = base.get_string(1)
	return {"edges": edges, "lines": lines, "names": names, "named": named, "bases": bases}


## The root and the files it extends, base after base. They ARE the root as far as a cut goes - a
## class cannot load without its base - so listing them as hubs would only say "the closure goes if
## the editor goes".
static func base_chain(graph: Dictionary, root_path: String) -> PackedStringArray:
	var bases: Dictionary = graph["bases"]
	var chain: PackedStringArray = PackedStringArray([root_path])
	var path: String = str(bases.get(root_path, ""))
	while not path.is_empty() and not chain.has(path):
		chain.append(path)
		path = str(bases.get(path, ""))
	return chain


## Everything reachable from `root_path`, sorted, never stepping onto `removed` (pass "" to remove
## nothing).
static func reach(edges: Dictionary, root_path: String, removed: String) -> PackedStringArray:
	var seen: Dictionary = {root_path: true}
	var queue: Array[String] = [root_path]
	while not queue.is_empty():
		var path: String = queue.pop_back()
		for target: String in edges.get(path, PackedStringArray()):
			if target != removed and not seen.has(target):
				seen[target] = true
				queue.append(target)
	var reached: PackedStringArray = PackedStringArray(seen.keys())
	reached.sort()
	return reached


## The LISTED files whose removal drops the most lines from the closure, largest first, ties by path
## so the list is the same on every run.
static func hubs(edges: Dictionary, lines: Dictionary, root_path: String,
		closure: PackedStringArray, kept: PackedStringArray) -> Array[Dictionary]:
	var total_lines: int = _sum_lines(closure, lines)
	var found: Array[Dictionary] = []
	for path: String in closure:
		if path == root_path or kept.has(path):
			continue
		var without: PackedStringArray = reach(edges, root_path, path)
		found.append({"path": path, "lines": total_lines - _sum_lines(without, lines),
			"files": closure.size() - without.size()})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["lines"] > b["lines"] or (a["lines"] == b["lines"] and str(a["path"]) < str(b["path"])))
	return found.slice(0, LISTED)


## The compile-time path references of one file, in source order: those whose opening sits in CODE
## rather than in a comment or a string, which the blanked text answers - blanking keeps every
## offset, and a reference that survived it still starts with its keyword there.
static func _path_references(pattern: RegEx, source: String, stripped: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for reference: RegExMatch in pattern.search_all(source):
		var start: int = reference.get_start()
		var keyword: String = source.substr(start, 7)
		if stripped.substr(start, 7) == keyword:
			found.append(reference.get_string(1))
	return found


## The source with every comment and string literal overwritten by spaces, newlines kept, so every
## offset and every line start in it is the same as in the source.
static func _blank(strip: RegEx, source: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	for found: RegExMatch in strip.search_all(source):
		parts.append(source.substr(cursor, found.get_start() - cursor))
		var pieces: PackedStringArray = found.get_string().split("\n")
		for index: int in pieces.size():
			if index > 0:
				parts.append("\n")
			parts.append(" ".repeat(pieces[index].length()))
		cursor = found.get_end()
	parts.append(source.substr(cursor))
	return "".join(parts)


static func _scripts_under(folder: String) -> Array[String]:
	var found: Array[String] = []
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		return found
	var children: PackedStringArray = directory.get_directories()
	children.sort()
	for child: String in children:
		found.append_array(_scripts_under(folder.path_join(child)))
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() == "gd":
			found.append(folder.path_join(file))
	return found


static func _sum_lines(paths: PackedStringArray, lines: Dictionary) -> int:
	var total: int = 0
	for path: String in paths:
		total += int(lines[path])
	return total


static func _label(path: String, graph: Dictionary) -> String:
	var named: Dictionary = graph["named"]
	if named.has(path):
		return "%s (%s)" % [named[path], path]
	return path
