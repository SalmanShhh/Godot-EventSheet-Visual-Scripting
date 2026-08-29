# Godot EventSheets - what the thing a row points at can actually do.
#
# Call Method and Connect Signal shipped years of Godot ago and their names are still typed strings:
# a row says `"grant_xp"` and nothing checks it, so a rename somewhere else rots it silently and a
# designer has to go and read the script to find out what to type in the first place.
#
# This is the reading that fixes both. Given the sheet and the expression a row is AIMED at, it works
# out which script that is - a node of the sheet's own scene, an Autoload, a class the project
# declares - and lists what it offers: every method and every signal it declares, with the arguments
# as written and the `##` comment above the declaration as its description. The programmers' own doc
# comments become the designer's tooltips, for free, in the file where they already live.
#
# DECLARED FIRST, THEN INHERITED. A script's own members are the ones somebody wrote for this game,
# so they lead; what the engine class underneath adds follows, named with the class it came from.
# Nothing here instantiates anything - a non-@tool script cannot be instantiated in the editor
# process at all, which is exactly where this runs - so it reads the FILE and asks ClassDB for the
# rest, the same two sources the vocabulary scanner already leans on.
@tool
class_name EventSheetScriptMembers
extends RefCounted

## file identity -> what that file declares. `path|mtime|size`, worked out once per file per session
## and dropped when the editor's filesystem ping fires, like every other by-file reader here.
static var _declared: Dictionary = {}

## Members never worth offering: the privacy convention every project shares, and Godot's own
## lifecycle callbacks, which a row does not call.
const _PRIVATE_PREFIX: String = "_"


## What one script declares: {"methods": Array[Dictionary], "signals": Array[Dictionary],
## "base": String}. Each member is {"name", "args", "doc"} - the arguments exactly as the file writes
## them, and the `##` block above the declaration joined into one line.
static func of_script(script_path: String) -> Dictionary:
	if script_path.strip_edges().is_empty() or not FileAccess.file_exists(script_path):
		return {"methods": [] as Array[Dictionary], "signals": [] as Array[Dictionary], "base": ""}
	var stamp: String = EventForgeFileStamp.of(script_path)
	if _declared.has(stamp):
		return _declared[stamp]
	var read: Dictionary = _read(script_path)
	_declared[stamp] = read
	return read


## Every method the thing at `expression` offers - what it declares first, then what its engine class
## adds. [] when the expression names nothing this can resolve, which is the honest answer: a row
## aimed at something worked out at run time keeps its typed string, and a list guessed at would be
## worse than no list.
static func methods_for(sheet: EventSheetResource, expression: String) -> Array[Dictionary]:
	var aimed: Dictionary = target_of(sheet, expression)
	if aimed.is_empty():
		return [] as Array[Dictionary]
	var members: Array[Dictionary] = []
	for method: Dictionary in (of_script(str(aimed.get("script_path", "")))["methods"] as Array[Dictionary]):
		members.append(method)
	_append_inherited(members, str(aimed.get("class", "")), "method")
	return members


## Every signal it offers, declared then inherited - the list Add event shows for a node or an
## Autoload, each with its parameters and its `##` line.
static func signals_for(sheet: EventSheetResource, expression: String) -> Array[Dictionary]:
	var aimed: Dictionary = target_of(sheet, expression)
	if aimed.is_empty():
		return [] as Array[Dictionary]
	var members: Array[Dictionary] = []
	for declared: Dictionary in (of_script(str(aimed.get("script_path", "")))["signals"] as Array[Dictionary]):
		members.append(declared)
	_append_inherited(members, str(aimed.get("class", "")), "signal")
	return members


## Which script a row's target expression names: {"script_path", "class", "label"}. {} when nothing
## in the project answers to it.
##
## The spellings a row actually holds: `self` and the empty target (the sheet's own script), `$Node`,
## `%Unique`, `get_node("Path")` and `$"/root/Autoload"` (a node of the scene this sheet is attached
## to), and a bare name that is an Autoload or a class the project declares.
static func target_of(sheet: EventSheetResource, expression: String) -> Dictionary:
	if sheet == null:
		return {}
	var text: String = _plain_reference(expression)
	if text.is_empty() or text == "self":
		return {"script_path": str(sheet.external_source_path), "class": str(sheet.host_class),
			"label": str(sheet.host_class)}
	for entry: Variant in EventSheetProjectScanner.list_project_classes():
		var named: Dictionary = entry as Dictionary
		if str(named.get("autoload", "")) == text or str(named.get("name", "")) == text:
			return {"script_path": str(named.get("path", "")), "class": "", "label": text}
	for node: Dictionary in _scene_nodes(sheet):
		if str(node.get("path", "")) == text or str(node.get("name", "")) == text:
			return {"script_path": str(node.get("script_path", "")),
				"class": str(node.get("type", "")), "label": str(node.get("name", ""))}
	return {}


## Every object of this project a row could listen to, each {"source", "label", "script_path"}: the
## nodes of the sheet's own scene that wear a script, then the project's Autoloads. `source` is what
## a trigger row stores - a node path, or `autoload:<Name>` for a singleton - which is the spelling
## the compiler already knows how to write a `_ready` connection for.
##
## Scripted objects only, and their DECLARED signals are what the picker offers off them: the engine
## signals of a Button are already browsable under Button, and one copy of each per node would be a
## picker nobody could read.
static func signal_sources(sheet: EventSheetResource) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if sheet == null:
		return sources
	for node: Dictionary in _scene_nodes(sheet):
		var script_path: String = str(node.get("script_path", ""))
		if script_path.is_empty() or str(node.get("path", "")) == ".":
			continue
		sources.append({"source": str(node.get("path", "")), "label": str(node.get("name", "")),
			"script_path": script_path})
	for entry: Variant in EventSheetProjectScanner.list_project_classes():
		var named: Dictionary = entry as Dictionary
		var autoload: String = str(named.get("autoload", ""))
		if autoload.is_empty():
			continue
		sources.append({"source": "autoload:%s" % autoload, "label": autoload,
			"script_path": str(named.get("path", ""))})
	return sources


## The detail line a picker or a completion entry shows for one member: its arguments, then its own
## description. "" for a member with neither, because an empty explanation is worse than none.
static func detail_of(member: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var args: String = str(member.get("args", "")).strip_edges()
	if not args.is_empty():
		parts.append(args)
	var doc: String = str(member.get("doc", "")).strip_edges()
	if not doc.is_empty():
		parts.append(doc)
	var from: String = str(member.get("from", "")).strip_edges()
	if parts.is_empty() and not from.is_empty():
		parts.append(EventSheetL10n.translate("from %s") % from)
	return " · ".join(parts)


## Drops the parsed files, so the next question re-reads them. The editor calls this when the
## filesystem changes, for the same reason every reader beside this one does.
static func clear_cache() -> void:
	_declared.clear()


## The file's own declarations, read once. A `##` block directly above a declaration is its
## description; a blank line or a statement between them breaks the block, exactly as Godot's own doc
## tool reads it.
static func _read(script_path: String) -> Dictionary:
	var methods: Array[Dictionary] = []
	var signal_members: Array[Dictionary] = []
	var base: String = ""
	var doc_lines: PackedStringArray = PackedStringArray()
	var method_head: RegEx = RegEx.create_from_string("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)")
	var signal_head: RegEx = RegEx.create_from_string("^signal ([A-Za-z_][A-Za-z0-9_]*)(?:\\((.*)\\))?")
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		if line.begins_with("##"):
			doc_lines.append(line.trim_prefix("##").strip_edges())
			continue
		if line.begins_with("extends "):
			base = line.trim_prefix("extends ").strip_edges()
		var found: RegExMatch = method_head.search(line)
		if found != null:
			if not found.get_string(1).begins_with(_PRIVATE_PREFIX):
				methods.append(_member(found.get_string(1), found.get_string(2), doc_lines))
		else:
			found = signal_head.search(line)
			if found != null and not found.get_string(1).begins_with(_PRIVATE_PREFIX):
				signal_members.append(_member(found.get_string(1), found.get_string(2), doc_lines))
		doc_lines = PackedStringArray()
	return {"methods": methods, "signals": signal_members, "base": base}


static func _member(name: String, args: String, doc_lines: PackedStringArray) -> Dictionary:
	return {"name": name, "args": args.strip_edges(), "doc": " ".join(doc_lines), "from": ""}


## What the engine class underneath adds, appended after what the file declares and named with the
## class it came from. A member the script already declares is not listed twice: the file's own one
## carries the description, and it is the one that answers.
static func _append_inherited(members: Array[Dictionary], class_text: String, kind: String) -> void:
	if class_text.strip_edges().is_empty() or not ClassDB.class_exists(class_text):
		return
	var seen: Dictionary = {}
	for member: Dictionary in members:
		seen[str(member["name"])] = true
	var infos: Array = ClassDB.class_get_signal_list(class_text) if kind == "signal" \
		else ClassDB.class_get_method_list(class_text)
	for info: Dictionary in infos:
		var name: String = str(info.get("name", ""))
		if name.is_empty() or name.begins_with(_PRIVATE_PREFIX) or seen.has(name):
			continue
		seen[name] = true
		# The engine's OWN sentence for a built-in member, in the same slot a script's `##` lines
		# fill - one convention, described once. "" until this machine has harvested the reference,
		# which reads exactly as it did before: an inherited member with nothing said about it.
		members.append({"name": name, "args": _argument_text(info),
			"doc": EventSheetDocEngineReference.member_description(class_text, name),
			"from": class_text})


## An engine member's arguments in the file's own spelling - `body: Node2D, index: int` - so a
## declared member and an inherited one read the same way in the same list.
static func _argument_text(info: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for argument: Dictionary in info.get("args", []):
		var argument_class: String = str(argument.get("class_name", ""))
		var argument_type: int = int(argument.get("type", TYPE_NIL))
		if not argument_class.is_empty():
			parts.append("%s: %s" % [str(argument.get("name", "")), argument_class])
		elif argument_type != TYPE_NIL:
			parts.append("%s: %s" % [str(argument.get("name", "")), type_string(argument_type)])
		else:
			parts.append(str(argument.get("name", "")))
	return ", ".join(parts)


## The nodes of the scene (or scenes) this sheet's script is attached to, each with the script it
## wears. Off the one scene reader every other scene fact comes off, so nothing here parses a `.tscn`.
static func _scene_nodes(sheet: EventSheetResource) -> Array:
	var nodes: Array = []
	var script_path: String = str(sheet.external_source_path)
	if script_path.strip_edges().is_empty():
		return nodes
	for scene_path: String in EventSheetSceneConnections.scenes_using_script(script_path):
		nodes.append_array(EventSheetSceneConnections.nodes_of_scene(scene_path))
	return nodes


## A target expression as the plain name it points at: `$Hurtbox`, `%Health`, `get_node("UI/Bar")`
## and `$"/root/Progress"` all mean the thing at the end of them.
static func _plain_reference(expression: String) -> String:
	var text: String = expression.strip_edges()
	if text.begins_with("get_node(") and text.ends_with(")"):
		text = text.substr(9, text.length() - 10).strip_edges()
	text = text.trim_prefix("$").trim_prefix("%")
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		text = text.substr(1, text.length() - 2)
	return text.trim_prefix("/root/").strip_edges()
