# EventSheet - "what will this script publish?" preview for the ACE provider wizard.
#
# Pointing the picker at one of your own scripts used to be an act of faith: you registered it and found
# out afterwards what joined the vocabulary. This answers the question BEFORE anything is registered, and
# it answers it with the SAME call the registry makes (EventSheetACEGenerator.generate_from_object), so
# the preview can never drift from what actually ships.
#
# Pure and headless-testable: scan() takes a path and returns a Dictionary. It reads the file, never
# writes it, and never touches the sheet or the registry - registration stays the caller's decision.
@tool
class_name EventSheetProviderPreview
extends RefCounted

## More verbs than this from one script and the picker starts to feel crowded, so the scan says so.
const BUSY_VERB_COUNT: int = 25


## Everything the wizard needs to render a decision, from one script path:
##   ok            - true when the script could be read and instantiated
##   reason        - why not, when ok is false (shown instead of the table)
##   provider_id   - the id its verbs will publish under
##   class_name    - the declared class_name, or "" when it falls back to the file name
##   entries       - one Dictionary per generated ACE: kind, kind_label, label, params, emits, source
##   counts        - per-kind totals, for the summary line
##   warnings      - plain-language notes about what will disappoint (see _warnings_for)
static func scan(script_path: String) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason": "", "provider_id": "", "class_name": "",
		"entries": [], "counts": {}, "warnings": []
	}
	var clean_path: String = script_path.strip_edges()
	if clean_path.is_empty() or not ResourceLoader.exists(clean_path):
		result["reason"] = "No such script: %s" % clean_path
		return result
	var resource: Resource = load(clean_path)
	if not (resource is Script):
		result["reason"] = "%s is not a script." % clean_path.get_file()
		return result
	var script: Script = resource as Script
	if not script.can_instantiate():
		# Abstract or erroring scripts cannot be reflected - the registry skips them silently, so say it.
		result["reason"] = "%s cannot be instantiated (it may be abstract, or have a script error)." % clean_path.get_file()
		return result
	var instance: Variant = script.new()
	if not (instance is Object):
		result["reason"] = "%s did not produce an object." % clean_path.get_file()
		return result

	var definitions: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_object(instance)
	var source: String = FileAccess.get_file_as_string(clean_path)
	result["ok"] = true
	result["class_name"] = str(script.get_global_name())
	for definition: ACEDefinition in definitions:
		var kind: int = definition.ace_type
		result["counts"][kind] = int(result["counts"].get(kind, 0)) + 1
		if str(result["provider_id"]).is_empty():
			result["provider_id"] = definition.provider_id
		(result["entries"] as Array).append({
			"kind": kind,
			"kind_label": kind_label(kind),
			"label": definition.display_name,
			"ace_id": definition.id,
			"params": _param_names(definition),
			# The literal code this row will emit. A method's template is baked at apply time, so it can
			# be empty here - say so rather than showing a blank cell that reads like a bug.
			"emits": str(definition.metadata.get("codegen_template", "")),
			"source": str(definition.metadata.get("source_kind", "")),
			"member": str(definition.metadata.get("source_name", "")),
		})
	result["warnings"] = _warnings_for(result, source, script)
	if instance is Node:
		(instance as Node).free()
	return result


## Human name for an ACEDefinition.ACEType, for the preview's kind column.
static func kind_label(kind: int) -> String:
	match kind:
		ACEDefinition.ACEType.CONDITION:
			return "Condition"
		ACEDefinition.ACEType.ACTION:
			return "Action"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expression"
		ACEDefinition.ACEType.TRIGGER:
			return "Trigger"
	return "?"


## A one-line summary: "12 verbs - 5 actions, 3 conditions, 3 expressions, 1 trigger".
static func summary_line(scan_result: Dictionary) -> String:
	if not bool(scan_result.get("ok", false)):
		return str(scan_result.get("reason", ""))
	var entries: Array = scan_result.get("entries", [])
	if entries.is_empty():
		return "No verbs - this script has no signals, exported properties or public methods to publish."
	var counts: Dictionary = scan_result.get("counts", {})
	var parts: PackedStringArray = PackedStringArray()
	for kind: int in [ACEDefinition.ACEType.ACTION, ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.EXPRESSION, ACEDefinition.ACEType.TRIGGER]:
		var count: int = int(counts.get(kind, 0))
		if count > 0:
			parts.append("%d %s%s" % [count, kind_label(kind).to_lower(), "s" if count != 1 else ""])
	return "%d verb%s - %s" % [entries.size(), "s" if entries.size() != 1 else "", ", ".join(parts)]


static func _param_names(definition: ACEDefinition) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for parameter: Variant in definition.parameters:
		if parameter is Dictionary:
			names.append(str((parameter as Dictionary).get("id", "")))
	return names


## The plain-language notes that stop a registration from disappointing. Each is something the author can
## act on in their own script, phrased as the fix rather than the complaint.
static func _warnings_for(scan_result: Dictionary, source: String, script: Script) -> Array:
	var warnings: Array = []
	var entries: Array = scan_result.get("entries", [])

	# An untyped `func foo():` cannot be classified: no return type means the generator can only assume
	# ACTION, so a boolean check silently lands in the wrong lane and its parameters lose their types.
	var untyped: PackedStringArray = _untyped_methods(source)
	if not untyped.is_empty():
		warnings.append({
			"kind": "untyped",
			"text": "%d method%s ha%s no return type, so %s published as Actions. Add `-> bool` for a Condition, or `-> float` / `-> String` for an Expression: %s" % [
				untyped.size(), "s" if untyped.size() != 1 else "", "ve" if untyped.size() != 1 else "s",
				"they are" if untyped.size() != 1 else "it is", ", ".join(untyped)],
		})

	# Without a class_name the provider id falls back to the file name. That is legal, but it is the name
	# the author will see all over the picker, so it should not be a surprise.
	if str(scan_result.get("class_name", "")).is_empty():
		warnings.append({
			"kind": "no_class_name",
			"text": "This script has no `class_name`, so its verbs publish under \"%s\" (taken from the file name). Add a `class_name` to control it." % scan_result.get("provider_id", ""),
		})

	if entries.size() > BUSY_VERB_COUNT:
		warnings.append({
			"kind": "busy",
			"text": "%d verbs will join the picker from this one script. Consider marking the internal ones `## @ace_hidden`." % entries.size(),
		})

	if entries.is_empty():
		warnings.append({
			"kind": "empty",
			"text": "Nothing to publish: only signals, `@export` properties and public methods declared in THIS script become verbs (inherited members and `_`-prefixed methods do not).",
		})

	# Reflection instantiates the script. A Node provider is targeted as $NodeName in the scene, so the
	# author needs to know a node of this type has to exist.
	if script.get_instance_base_type() == "Node" or ClassDB.is_parent_class(script.get_instance_base_type(), "Node"):
		warnings.append({
			"kind": "node_target",
			"text": "This is a Node script, so its verbs target a node in the scene (the row's On-node field). Its rows need that node present to run.",
		})
	return warnings


## Every `func name(...)` in the source with no `-> Type`, which is what forces the ACTION fallback.
static func _untyped_methods(source: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	# Top-level funcs only (no leading whitespace), skipping `_`-prefixed ones - they are never published.
	if regex.compile("(?m)^func\\s+([a-zA-Z][A-Za-z0-9_]*)\\s*\\([^)]*\\)\\s*:") != OK:
		return names
	for match_result: RegExMatch in regex.search_all(source):
		names.append(match_result.get_string(1))
	return names
