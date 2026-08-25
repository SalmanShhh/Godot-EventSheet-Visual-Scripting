@tool
class_name EventSheetAddBehavior
extends RefCounted

# The two ways a pack joins an object, as pure functions the Add behavior dialog drives.
#
#   as a behavior node   - a Node carrying the pack's script is added under the object in the
#                          scene, with the properties the dialog collected already set. This is
#                          how every pack works, and it is the first option for that reason.
#                          A pack that ships a SCENE of its own (a full-screen effects layer needs
#                          a CanvasLayer with a rectangle under it, which a bare Node cannot be)
#                          has that scene dropped in instead, and is otherwise identical.
#   written into this script - only where the pack declares `## @ace_inline_capable`: the pack's
#                          knobs become the script's own instance variables, so a small shape
#                          (a cooldown, a wrap, a pin) lives in the file rather than in a
#                          separate node. The pack's actions still come from the pack.
#
# Nothing here knows about a dialog: the dialog collects a pack, a host and a property map, and
# these apply it.


## Every knob a pack publishes, in file order, each as {"id", "type", "default", "name"}.
## Read from the pack's own source rather than an instance, so it works headless and needs no
## scene: a pack is a script, and `@export var speed: float = 200.0` says everything.
static func exported_properties(script_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return out
	var source: String = FileAccess.get_file_as_string(script_path)
	var pattern: RegEx = RegEx.create_from_string(
		"(?m)^@export[^\\n]*\\n?\\s*var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([A-Za-z_][A-Za-z0-9_\\[\\]]*))?\\s*:?=\\s*([^\\n#]*)")
	for found: RegExMatch in pattern.search_all(source):
		var identifier: String = found.get_string(1)
		var declared_type: String = found.get_string(2).strip_edges()
		var default_text: String = found.get_string(3).strip_edges()
		if declared_type.is_empty():
			declared_type = _infer_type(default_text)
		out.append({
			"id": identifier,
			"type": declared_type,
			"default": default_text,
			"name": _humanize(identifier),
		})
	return out


## Adds a Node carrying the pack's script under `host`, with `values` (id -> text) applied to the
## properties the pack publishes. Returns {"ok", "message", optional "node"}.
static func attach_node(pack: Dictionary, host: Node, values: Dictionary) -> Dictionary:
	var script_path: String = str(pack.get("path", ""))
	if host == null:
		return {"ok": false, "message": "Pick the object to add the behavior to first."}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return {"ok": false, "message": "%s has no script to attach." % str(pack.get("name", "the pack"))}
	var pack_script: Script = load(script_path)
	if pack_script == null:
		return {"ok": false, "message": "%s did not load." % script_path.get_file()}
	var shipped: Dictionary = EventSheetPackAssets.shipped_by(script_path)
	var behavior: Node = _pack_node(pack, pack_script, str(shipped.get("scene", "")))
	if behavior == null:
		return {"ok": false, "message": "%s ships a scene of its own and it did not open." % str(pack.get("name", "The pack"))}
	host.add_child(behavior)
	behavior.owner = host.owner if host.owner != null else host
	var applied: PackedStringArray = PackedStringArray()
	for property: Dictionary in exported_properties(script_path):
		var identifier: String = str(property.get("id", ""))
		if not values.has(identifier):
			continue
		var parsed: Variant = parse_value(str(values[identifier]), str(property.get("type", "")))
		behavior.set(identifier, parsed)
		applied.append(identifier)
	var message: String = "Added %s to %s." % [str(pack.get("name", "")), host.name]
	if not applied.is_empty():
		message += " Set %s." % ", ".join(applied)
	# A pack that brings its own SCENE has already dressed itself - the scene names the shader its own
	# nodes wear - so only a pack that is a bare behaviour needs its effect installing on the host.
	if str(shipped.get("scene", "")).is_empty():
		message += _install_shipped_effect(str(shipped.get("shader", "")), host)
	var requirement: String = host_requirement(pack)
	if not requirement.is_empty() and not host.is_class(requirement):
		message += " Note: this pack expects a %s - the Doctor will say so until it has one." % requirement
	return {"ok": true, "message": message, "node": behavior}


## The node a pack joins the scene as: its own scene when it ships one, otherwise a bare Node
## carrying its script. Null only when a shipped scene refuses to open, which is worth saying rather
## than silently falling back to a Node the pack's script cannot even be set on.
static func _pack_node(pack: Dictionary, pack_script: Script, shipped_scene: String) -> Node:
	if not shipped_scene.is_empty():
		var packed: PackedScene = ResourceLoader.load(shipped_scene, "PackedScene") as PackedScene
		return null if packed == null else packed.instantiate()
	var behavior: Node = Node.new()
	behavior.name = str(pack.get("name", "Behavior")).replace(" ", "")
	behavior.set_script(pack_script)
	return behavior


## Copies a pack's shader into the project and puts its material on the node, and says in plain
## words what that did. The empty string when the pack ships no shader, which is most of them.
static func _install_shipped_effect(shipped_shader: String, host: Node) -> String:
	if shipped_shader.is_empty():
		return ""
	var effect: Dictionary = EventSheetPackAssets.install(shipped_shader)
	if not bool(effect.get("ok", false)):
		return " %s could not be copied into the project - check that res://effects is writable." % shipped_shader.get_file()
	var created: PackedStringArray = effect.get("created", PackedStringArray())
	EventSheetPackAssets.notice_new_files(created)
	var material_path: String = str(effect.get("material_path", ""))
	var said: String = " Used the %s already in %s." % [material_path.get_file(), EventSheetPackAssets.DEFAULT_FOLDER]
	if not created.is_empty():
		said = " Copied %s into %s - it is yours to edit." % [
			", ".join(created), EventSheetPackAssets.DEFAULT_FOLDER]
	if EventSheetPackAssets.wear_material(host, material_path):
		return said + " %s wears it now." % host.name
	if host is CanvasItem and (host as CanvasItem).material is ShaderMaterial:
		return said + " %s already wears a shader material, so that one was left alone." % host.name
	return said + " Put it on a 2D node or a Control to see it - %s cannot wear a material." % host.name


## The pack's shape written into a sheet instead of attached: its knobs become the sheet's own
## exported instance variables. Mutates `sheet` and returns {"ok", "message"} - the caller runs
## it inside the undo funnel.
##
## What this does NOT do, said plainly rather than implied: the pack's conditions and actions
## still come from the pack. Writing the properties in is what makes the knobs the script's own,
## which is the whole difference an inline-capable pack offers.
static func write_into_sheet(pack: Dictionary, sheet: EventSheetResource, values: Dictionary) -> Dictionary:
	if sheet == null:
		return {"ok": false, "message": "Open a sheet to write the behavior into."}
	if not bool(pack.get("inline_capable", false)):
		return {"ok": false, "message": "%s can only be added as a behavior node - it does not declare that its shape can be written into a script." % str(pack.get("name", "This pack"))}
	var written: PackedStringArray = PackedStringArray()
	var skipped: PackedStringArray = PackedStringArray()
	for property: Dictionary in exported_properties(str(pack.get("path", ""))):
		var identifier: String = str(property.get("id", ""))
		if identifier.is_empty() or not identifier.is_valid_identifier():
			continue
		if sheet.variables.has(identifier):
			skipped.append(identifier)
			continue
		var default_text: String = str(values.get(identifier, property.get("default", "")))
		sheet.variables[identifier] = {
			"type": _sheet_type_for(str(property.get("type", ""))),
			"default": parse_value(default_text, str(property.get("type", ""))),
			"exported": true,
		}
		written.append(identifier)
	if written.is_empty() and skipped.is_empty():
		return {"ok": false, "message": "%s publishes no properties to write in." % str(pack.get("name", "This pack"))}
	var message: String = "Wrote %s into this script: %s." % [str(pack.get("name", "")), ", ".join(written)] \
		if not written.is_empty() else "%s was already written in." % str(pack.get("name", ""))
	if not skipped.is_empty():
		message += " Left alone (already declared here): %s." % ", ".join(skipped)
	return {"ok": true, "message": message}


## The host class a pack needs, from its own `## @ace_requires(...)`. "" when it needs none.
static func host_requirement(pack: Dictionary) -> String:
	var script_path: String = str(pack.get("path", ""))
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return ""
	var pattern: RegEx = RegEx.create_from_string("(?m)^\\s*#+\\s*@ace_requires\\(\\s*\"?([A-Za-z_][A-Za-z0-9_]*)\"?")
	var found: RegExMatch = pattern.search(FileAccess.get_file_as_string(script_path))
	return "" if found == null else found.get_string(1)


## Text from a property field to the value the pack's property wants. Deliberately small: the
## dialog's fields are text, and a pack's knobs are numbers, flags, strings and vectors.
static func parse_value(text: String, declared_type: String) -> Variant:
	var trimmed: String = text.strip_edges()
	match declared_type:
		"int":
			return int(trimmed) if trimmed.is_valid_int() else 0
		"float":
			return float(trimmed) if trimmed.is_valid_float() else 0.0
		"bool":
			return trimmed.to_lower() == "true"
		"Vector2":
			var parts: PackedStringArray = trimmed.trim_prefix("Vector2(").trim_suffix(")").split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0]), float(parts[1]))
			return Vector2.ZERO
		"String", "StringName":
			return trimmed.trim_prefix("\"").trim_suffix("\"")
	if trimmed.is_valid_int():
		return int(trimmed)
	if trimmed.is_valid_float():
		return float(trimmed)
	if trimmed.to_lower() == "true" or trimmed.to_lower() == "false":
		return trimmed.to_lower() == "true"
	return trimmed.trim_prefix("\"").trim_suffix("\"")


static func _sheet_type_for(declared_type: String) -> String:
	match declared_type:
		"int":
			return "int"
		"bool":
			return "bool"
		"String", "StringName":
			return "String"
		"Vector2":
			return "Vector2"
	return "float"


static func _infer_type(default_text: String) -> String:
	var trimmed: String = default_text.strip_edges()
	if trimmed.begins_with("\""):
		return "String"
	if trimmed.to_lower() == "true" or trimmed.to_lower() == "false":
		return "bool"
	if trimmed.begins_with("Vector2"):
		return "Vector2"
	if trimmed.is_valid_int():
		return "int"
	if trimmed.is_valid_float():
		return "float"
	return ""


static func _humanize(identifier: String) -> String:
	var words: PackedStringArray = identifier.replace("_", " ").strip_edges().split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for index: int in words.size():
		var word: String = words[index]
		out.append(word.substr(0, 1).to_upper() + word.substr(1) if index == 0 else word)
	return " ".join(out)
