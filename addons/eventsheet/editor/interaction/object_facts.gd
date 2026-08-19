@tool
class_name EventSheetObjectFacts
extends RefCounted

# Q1/Q2 - what an object IS, as opposed to what one file does with it.
#
# The census (viewport_reading_rows.gd) answers "what does THIS sheet do with this object": how many
# rows name it, which verbs, which signals. That is half the question a reader has. The other half -
# which instance variables it carries, which functions and triggers it offers, which behaviors ride
# on it, which families it belongs to - is a fact about the OBJECT, and it lives in two places the
# sheet does not: the object's own script file, and the scene it is placed in.
#
# Everything here reads those two as TEXT and nothing else. No scene is instantiated, no script is
# loaded and run, nothing is opened in the editor: a rail refresh and a popup open both run this, and
# a popup that instantiates a scene to answer "what behaviors are on it" would open a project's worth
# of side effects behind one click. Text also means headless works exactly like the editor does.
#
# Display-free and static, so a test pins the exact answers without a display server.


## Node types whose texture is worth using as an object's picture (Q10).
const PICTURE_TYPES: PackedStringArray = [
	"Sprite2D", "Sprite3D", "AnimatedSprite2D", "AnimatedSprite3D", "TextureRect", "TextureButton"
]

## GDScript's own callbacks. They are the engine calling the object, never something a sheet calls on
## it, so they are not functions the object OFFERS - and a list led by `_ready` and `_process` buries
## the two the reader came for.
const ENGINE_CALLBACK_PREFIX := "_"

static var _script_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}


## Drops every cached read. The editor calls this when the filesystem changes; tests call it between
## fixtures so one fixture's scene cannot answer for the next one's.
static func clear_cache() -> void:
	_script_cache.clear()
	_scene_cache.clear()


# ── The object's own script ───────────────────────────────────────────────────────────────────


## What one .gd file says the object HAS, as
##   {"variables": Array[{name, display}],
##    "functions": Array[{name, display, params, condition}],
##    "triggers":  Array[{name, display, params}],
##    "families":  PackedStringArray}
## Empty for a path that is not a readable .gd. Cached for the session: the answer only changes when
## the file does, and the editor drops the cache on a filesystem change.
static func script_facts(script_path: String) -> Dictionary:
	var path: String = script_path.strip_edges()
	if path.is_empty() or path.get_extension().to_lower() != "gd":
		return {}
	if _script_cache.has(path):
		return _script_cache[path]
	var facts: Dictionary = _read_script_facts(path)
	_script_cache[path] = facts
	return facts


static func _read_script_facts(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var facts: Dictionary = {
		"variables": [], "functions": [], "triggers": [], "families": PackedStringArray()
	}
	if text.is_empty():
		return facts
	var seen_family: Dictionary = {}
	for line: String in text.split("\n"):
		# `add_to_group("enemies")` can sit at any indent, so families are read from every line; the
		# declarations below are top-level only, which is what "the object has" means.
		var family: String = _group_argument(line)
		if not family.is_empty() and not seen_family.has(family):
			seen_family[family] = true
			(facts["families"] as PackedStringArray).append(family)
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var stripped: String = line.strip_edges()
		if stripped.begins_with("signal "):
			var trigger: Dictionary = _declaration_parts(stripped.substr("signal ".length()))
			if not str(trigger.get("name", "")).is_empty():
				(facts["triggers"] as Array).append({
					"name": trigger["name"],
					"display": trigger_display(str(trigger["name"])),
					"params": trigger.get("params", PackedStringArray())
				})
			continue
		if stripped.begins_with("func "):
			var declared: Dictionary = _declaration_parts(stripped.substr("func ".length()))
			var function_name: String = str(declared.get("name", ""))
			if function_name.is_empty() or function_name.begins_with(ENGINE_CALLBACK_PREFIX):
				continue
			(facts["functions"] as Array).append({
				"name": function_name,
				"display": EventSheetViewportLenses.humanize_identifier(function_name, true),
				"params": declared.get("params", PackedStringArray()),
				"condition": str(declared.get("return", "")) == "bool"
			})
			continue
		var variable_name: String = _variable_name(stripped)
		if not variable_name.is_empty():
			(facts["variables"] as Array).append({
				"name": variable_name,
				"display": EventSheetViewportLenses.humanize_identifier(variable_name)
			})
	return facts


## A signal read as the trigger it is: `died` -> `On Died`, `body_entered` -> `On Body Entered`.
static func trigger_display(signal_name: String) -> String:
	var humanized: String = EventSheetViewportLenses.humanize_identifier(signal_name, true)
	return EventSheetL10n.translate("On %s") % humanized


## The name / parameter names / declared return of a `func` or `signal` declaration body (everything
## after the keyword). Parameter TYPES and defaults are dropped: a reader wants the slots, not the
## signature.
static func _declaration_parts(declaration: String) -> Dictionary:
	var text: String = declaration.strip_edges()
	var open: int = text.find("(")
	if open < 0:
		return {"name": text.trim_suffix(":").strip_edges(), "params": PackedStringArray(), "return": ""}
	var declared_name: String = text.substr(0, open).strip_edges()
	var close: int = text.rfind(")")
	var inside: String = text.substr(open + 1, maxi(close - open - 1, 0))
	var params: PackedStringArray = PackedStringArray()
	for piece: String in _split_arguments(inside):
		var bare: String = piece.strip_edges().get_slice(":", 0).get_slice("=", 0).strip_edges()
		if not bare.is_empty():
			params.append(bare)
	var returned: String = ""
	var arrow: int = text.find("->", maxi(close, 0))
	if arrow >= 0:
		returned = text.substr(arrow + 2).trim_suffix(":").strip_edges()
	return {"name": declared_name, "params": params, "return": returned}


## Splits an argument list on top-level commas, so `pos: Vector2 = Vector2(0, 0)` stays one argument.
static func _split_arguments(inside: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for index: int in inside.length():
		var character: String = inside[index]
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		if character == "," and depth <= 0:
			parts.append(current)
			current = ""
			continue
		current += character
	parts.append(current)
	return parts


## The name a top-level `var` line declares, "" for anything that is not one. `const` is deliberately
## not a variable: it is a value the file fixes once, not a slot the object carries.
static func _variable_name(stripped: String) -> String:
	var text: String = stripped
	for annotation: String in ["@export", "@onready", "@tool"]:
		if text.begins_with(annotation):
			var space: int = text.find(" ")
			if space < 0:
				return ""
			text = text.substr(space + 1).strip_edges()
	if text.begins_with("@"):
		var gap: int = text.find(" ")
		if gap < 0:
			return ""
		text = text.substr(gap + 1).strip_edges()
	if not text.begins_with("var "):
		return ""
	var declared: String = text.substr(4).strip_edges().get_slice(":", 0).get_slice("=", 0).strip_edges()
	return declared if EventSheetViewportLenses.is_identifier(declared) else ""


## The group name an `add_to_group("x")` line names, "" when the line is not one. A group added by
## expression rather than by literal is skipped: half a name is worse than none.
static func _group_argument(line: String) -> String:
	var marker: String = "add_to_group("
	var start: int = line.find(marker)
	if start < 0:
		return ""
	var rest: String = line.substr(start + marker.length())
	var quote: String = "\"" if rest.begins_with("\"") else ("'" if rest.begins_with("'") else "")
	if quote.is_empty():
		return ""
	var end: int = rest.find(quote, 1)
	return rest.substr(1, end - 1) if end > 1 else ""


# ── The scene the object is placed in ─────────────────────────────────────────────────────────


## One .tscn read back as the facts a sheet needs from it:
##   {"root": String, "root_type": String,
##    "behaviors": Array[{name, node, properties: Array[{name, value}]}],
##    "families": PackedStringArray,
##    "children": Array[{name, type, script}],
##    "picture": String}
## `behaviors` are the pack nodes mounted under the root, `families` the root's persistent groups,
## `picture` the first texture found on or under the root (Q10). {} for a path that is not readable.
static func scene_facts(scene_path: String) -> Dictionary:
	var path: String = scene_path.strip_edges()
	if path.is_empty() or path.get_extension().to_lower() != "tscn":
		return {}
	if _scene_cache.has(path):
		return _scene_cache[path]
	var facts: Dictionary = _read_scene_facts(path)
	_scene_cache[path] = facts
	return facts


static func _read_scene_facts(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var facts: Dictionary = {
		"root": "", "root_type": "", "root_script": "", "behaviors": [],
		"families": PackedStringArray(), "children": [], "picture": ""
	}
	if text.is_empty():
		return facts
	var resources: Dictionary = {}
	var packs: Dictionary = EventSheetViewportReadingRows.behaviour_pack_index()
	var current: Dictionary = {}
	var nodes: Array = []
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource "):
			resources[_attribute(line, "id")] = _attribute(line, "path")
			continue
		if line.begins_with("[node "):
			current = {
				"name": _attribute(line, "name"),
				"type": _attribute(line, "type"),
				"parent": _attribute(line, "parent"),
				"has_parent": line.contains("parent="),
				"script": "",
				"groups": _string_array_value(line, "groups"),
				"texture": ""
			}
			nodes.append(current)
			continue
		if line.begins_with("[") or current.is_empty():
			continue
		if line.begins_with("script = ExtResource("):
			current["script"] = str(resources.get(_first_quoted(line), ""))
		elif line.begins_with("texture = ExtResource("):
			current["texture"] = str(resources.get(_first_quoted(line), ""))
		elif line.contains(" = ") and not line.begins_with("metadata/"):
			current[_property_key(line)] = line.get_slice(" = ", 1).strip_edges()
	for entry: Variant in nodes:
		var node: Dictionary = entry
		if not bool(node.get("has_parent", false)):
			facts["root"] = str(node.get("name", ""))
			facts["root_type"] = str(node.get("type", ""))
			facts["root_script"] = str(node.get("script", ""))
			facts["families"] = node.get("groups", PackedStringArray())
			continue
		var behavior: String = _pack_name_of(str(node.get("script", "")), str(node.get("type", "")), packs)
		if behavior.is_empty():
			facts["children"].append({
				"name": str(node.get("name", "")),
				"type": str(node.get("type", "")),
				"script": str(node.get("script", "")),
				"parent": str(node.get("parent", "")),
				"groups": node.get("groups", PackedStringArray()),
				"texture": str(node.get("texture", ""))
			})
		else:
			facts["behaviors"].append({
				"name": behavior,
				"node": str(node.get("name", "")),
				"properties": _behavior_properties(node)
			})
		if str(facts["picture"]).is_empty() and Array(PICTURE_TYPES).has(str(node.get("type", ""))):
			facts["picture"] = str(node.get("texture", ""))
	return facts


## The pack a scene node IS, "" when it is an ordinary node. A pack node is recognised by the folder
## its script lives in (`res://eventsheet_addons/<pack>/`) or by its declared type being a pack class,
## which are the same two ways the census recognises one.
static func _pack_name_of(script_path: String, node_type: String, packs: Dictionary) -> String:
	if not node_type.is_empty() and packs.has(node_type):
		return str(packs[node_type])
	if script_path.is_empty():
		return ""
	var folder: String = script_path.get_base_dir().get_file().to_pascal_case()
	return str(packs.get(folder, ""))


## The properties a behavior node has set IN THE SCENE, as {name, value} in file order - "Health ▸
## max hp = 50" is exactly this, and it is the answer to "what is this behavior set to here".
static func _behavior_properties(node: Dictionary) -> Array:
	var reserved: PackedStringArray = PackedStringArray([
		"name", "type", "parent", "has_parent", "script", "groups", "texture"
	])
	var properties: Array = []
	for key: Variant in node:
		var property_name: String = str(key)
		if Array(reserved).has(property_name) or property_name.contains("/"):
			continue
		properties.append({
			"name": EventSheetViewportLenses.humanize_identifier(property_name),
			"value": str(node[key])
		})
	return properties


## The behaviors and families of the object one SHEET drives, or {} when no scene uses its script as
## a root. Both halves are what an event sheet's object carries, recovered from where Godot keeps
## them: pack nodes in the scene, and the root's persistent groups plus its own `add_to_group` lines.
static func sheet_object_facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var source_path: String = str(sheet.get("external_source_path")).strip_edges()
	if source_path.is_empty():
		return {}
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(source_path)
	var facts: Dictionary = scene_facts(str(scene.get("scene_path", "")))
	var families: PackedStringArray = PackedStringArray(facts.get("families", PackedStringArray()))
	for coded: String in PackedStringArray(script_facts(source_path).get("families", PackedStringArray())):
		if not Array(families).has(coded):
			families.append(coded)
	return {
		"behaviors": facts.get("behaviors", []),
		"families": families,
		"scene_path": str(scene.get("scene_path", "")),
		"picture": str(facts.get("picture", ""))
	}


## The .gd file that says what ONE census entry is, "" when nothing in the project does. The sheet's
## own object answers with the open file; a node or behaviour with the script the scene mounts on it;
## a spawned scene with its root's script; a global with the file the autoload names.
static func script_path_for_entry(entry: Dictionary, sheet_source_path: String) -> String:
	var kind: String = str(entry.get("kind", ""))
	if kind == "script":
		return sheet_source_path
	if kind == "autoload":
		var declared: String = str(entry.get("path", "")).strip_edges().trim_prefix("*")
		return declared if declared.get_extension().to_lower() == "gd" else ""
	if kind == "scene":
		return str(scene_facts(str(entry.get("path", ""))).get("root_script", ""))
	if not (kind in ["node", "behaviour"]) or sheet_source_path.strip_edges().is_empty():
		return ""
	var scene_path: String = str(ViewportRowBuilder.scene_using_script(sheet_source_path).get("scene_path", ""))
	if scene_path.is_empty():
		return ""
	var label: String = str(entry.get("label", ""))
	var facts: Dictionary = scene_facts(scene_path)
	for child_entry: Variant in facts.get("children", []):
		var child: Dictionary = child_entry
		if str(child.get("name", "")) == label:
			return str(child.get("script", ""))
	return ""


## Everything ONE census entry IS, for the Object properties popup (Q1):
##   {"variables", "functions", "triggers", "behaviors", "families"}
## The first three come from the object's own script, the last two from the scene it is placed in
## plus its own `add_to_group` lines - which is where Godot keeps each of them.
static func facts_for_entry(entry: Dictionary, sheet_source_path: String) -> Dictionary:
	var script_path: String = script_path_for_entry(entry, sheet_source_path)
	var script: Dictionary = script_facts(script_path)
	var behaviors: Array = []
	var families: PackedStringArray = PackedStringArray(script.get("families", PackedStringArray()))
	var kind: String = str(entry.get("kind", ""))
	var scene_path: String = ""
	if kind == "scene":
		scene_path = str(entry.get("path", ""))
	elif not sheet_source_path.strip_edges().is_empty():
		scene_path = str(ViewportRowBuilder.scene_using_script(sheet_source_path).get("scene_path", ""))
	var scene: Dictionary = scene_facts(scene_path)
	if kind in ["script", "scene"]:
		behaviors = scene.get("behaviors", [])
		for group_name: String in PackedStringArray(scene.get("families", PackedStringArray())):
			if not Array(families).has(group_name):
				families.append(group_name)
	elif kind == "node":
		for child_entry: Variant in scene.get("children", []):
			var child: Dictionary = child_entry
			if str(child.get("name", "")) != str(entry.get("label", "")):
				continue
			for group_name: String in PackedStringArray(child.get("groups", PackedStringArray())):
				if not Array(families).has(group_name):
					families.append(group_name)
	return {
		"variables": script.get("variables", []),
		"functions": script.get("functions", []),
		"triggers": script.get("triggers", []),
		"behaviors": behaviors,
		"families": families,
		"script_path": script_path
	}


## Q4 - what a sheet is ABOUT, for the places that name it: the tab, the Open Sheets list, the window
## title and the recents. Returns {"name", "note", "icon_class", "file"}.
##
## The name is the one the Include bar already shows, resolved by the same ladder so a tab and the head
## bar under it can never disagree: a pack's own display name, else the `class_name`, else the ROOT NODE
## of the scene the script drives, else the file name (which is where a file name belongs - last).
static func sheet_object_title(sheet: EventSheetResource, explicit_path: String) -> Dictionary:
	var file_path: String = explicit_path.strip_edges()
	if sheet == null:
		return {"name": file_path.get_file().get_basename(), "note": "", "icon_class": "", "file": file_path}
	var source_path: String = str(sheet.get("external_source_path")).strip_edges()
	if source_path.is_empty():
		source_path = file_path
	var declared: String = sheet.custom_class_name.strip_edges()
	var note: String = ""
	var name_text: String = ""
	var pack: String = str(EventSheetViewportReadingRows.behaviour_pack_index().get(declared, "")) \
		if not declared.is_empty() else ""
	if not pack.is_empty():
		name_text = pack
		note = EventSheetL10n.translate("addon pack")
	elif is_global_script(source_path):
		name_text = declared if not declared.is_empty() else source_path.get_file().get_basename().to_pascal_case()
		note = EventSheetL10n.translate("global")
	elif not declared.is_empty():
		name_text = declared
	else:
		name_text = str(ViewportRowBuilder.scene_using_script(source_path).get("root_name", ""))
	if name_text.is_empty():
		name_text = (source_path if not source_path.is_empty() else file_path).get_file().get_basename()
	return {
		"name": name_text,
		"note": note,
		"icon_class": sheet.host_class.strip_edges(),
		"file": source_path if not source_path.is_empty() else file_path
	}


## True when a script is one of the project's autoload singletons - a sheet about a GLOBAL, which is
## what an event sheet calls an object every layout can reach.
static func is_global_script(script_path: String) -> bool:
	if script_path.strip_edges().is_empty():
		return false
	var autoloads: Dictionary = EventSheetViewportReadingRows.autoload_singletons()
	for singleton: String in autoloads:
		if str(autoloads[singleton]) == script_path:
			return true
	return false


## The texture one NAMED node of a scene carries, "" when that node has none (or is not there). What
## lets a `$Sprite2D` row wear its own picture rather than the scene's (Q10).
static func picture_of_node(scene_path: String, node_name: String) -> String:
	var facts: Dictionary = scene_facts(scene_path)
	if facts.is_empty():
		return ""
	for entry: Variant in facts.get("children", []):
		var child: Dictionary = entry
		if str(child.get("name", "")) == node_name.strip_edges():
			return str(child.get("texture", ""))
	return ""


## `key="value"` out of a .tscn header line, "" when the key is absent.
static func _attribute(line: String, key: String) -> String:
	var marker: String = "%s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


## `key=PackedStringArray("a", "b")` out of a .tscn header line - how the editor writes persistent
## groups. Empty when the key is absent or holds nothing.
static func _string_array_value(line: String, key: String) -> PackedStringArray:
	var marker: String = "%s=" % key
	var start: int = line.find(marker)
	if start < 0:
		return PackedStringArray()
	var open: int = line.find("(", start)
	var close: int = line.find(")", open)
	if open < 0 or close < open:
		return PackedStringArray()
	var values: PackedStringArray = PackedStringArray()
	for piece: String in line.substr(open + 1, close - open - 1).split(","):
		var bare: String = piece.strip_edges().trim_prefix("\"").trim_suffix("\"")
		if not bare.is_empty():
			values.append(bare)
	return values


## The first quoted token of a line - the ExtResource id in `script = ExtResource("2_abc")`.
static func _first_quoted(line: String) -> String:
	var open: int = line.find("\"")
	if open < 0:
		return ""
	var close: int = line.find("\"", open + 1)
	return line.substr(open + 1, close - open - 1) if close > open else ""


## The property name a `key = value` scene line sets.
static func _property_key(line: String) -> String:
	return line.get_slice(" = ", 0).strip_edges()
