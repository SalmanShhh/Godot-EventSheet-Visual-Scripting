# EventSheet — AI-assisted event generation ("describe → events").
#
# Closes the loop the MCP server already enables, but inside the editor: a plain-English
# description is turned into a grounded prompt, an LLM returns GDScript, and that GDScript is
# run through the SAME lossless GDScript→events lifter the editor's paste uses — so the result
# lands as ordinary, editable event rows, never opaque generated code.
#
# The LLM call itself is injectable: tests (and any offline flow) set `response_provider` to a
# Callable(prompt) -> String; the live editor falls back to an HTTP call configured by the
# `eventsheets/ai/*` project settings. The grounding + lift pipeline is fully testable either way.
@tool
class_name EventSheetAIGeneration
extends RefCounted

## Test/offline override: a Callable taking the prompt String and returning GDScript text.
## When set, it replaces the live LLM HTTP call (so the pipeline is deterministically testable).
static var response_provider: Callable = Callable()


## Builds the grounded prompt: the host class + the sheet's variables so the model references
## real symbols, and a firm "GDScript only" instruction so the output lifts cleanly.
static func build_prompt(description: String, sheet: EventSheetResource) -> String:
	var host: String = sheet.host_class if sheet != null and not sheet.host_class.is_empty() else "Node"
	var variable_names: Array = []
	if sheet != null:
		for key: Variant in sheet.variables.keys():
			variable_names.append(str(key))
	var variables_line: String = ", ".join(_to_strings(variable_names)) if not variable_names.is_empty() else "(none)"
	return "\n".join(PackedStringArray([
		"You are generating Godot 4 GDScript that will run inside an event sheet.",
		"Host node type: %s." % host,
		"Sheet variables you may read/write: %s." % variables_line,
		"Write ONLY GDScript statements (no markdown fences, no function wrapper, no class line)",
		"implementing this behavior:",
		description.strip_edges(),
		"Prefer the sheet's variables and the host node; keep it to a few clear statements."
	]))


## Runs generated GDScript through the lossless lifter and returns the editable rows it
## produces: {rows: [Resource…], error}. (The same conversion MCP apply_snippet uses.)
static func generate_rows(description: String, sheet: EventSheetResource, gdscript_text: String) -> Dictionary:
	var text: String = _strip_fences(gdscript_text)
	if text.strip_edges().is_empty():
		return {"rows": [], "error": "the model returned nothing"}
	var converted: EventSheetResource = GDScriptImporter.new().import_external_source(text)
	var rows: Array = []
	for row: Variant in converted.events:
		# Drop the synthetic `extends …` prelude the importer adds for bare snippets.
		if row is RawCodeRow and (row as RawCodeRow).code.strip_edges().begins_with("extends "):
			continue
		rows.append(row)
	if rows.is_empty():
		return {"rows": [], "error": "the generated GDScript produced no events"}
	return {"rows": rows, "error": ""}


## True when an in-editor LLM call is configured (an API key project setting). When false, the
## editor points the user at Project Settings or the MCP server instead of failing silently.
static func is_live_configured() -> bool:
	return not str(ProjectSettings.get_setting("eventsheets/ai/api_key", "")).strip_edges().is_empty()


## Resolves a description to GDScript: the injected provider if set, else "" (caller does the
## live HTTP call). Kept separate so the grounding stays one place.
static func resolve_gdscript(description: String, sheet: EventSheetResource) -> String:
	if response_provider.is_valid():
		return str(response_provider.call(build_prompt(description, sheet)))
	return ""


static func _strip_fences(text: String) -> String:
	var stripped: String = text.strip_edges()
	if stripped.begins_with("```"):
		var first_newline: int = stripped.find("\n")
		if first_newline != -1:
			stripped = stripped.substr(first_newline + 1)
		if stripped.ends_with("```"):
			stripped = stripped.substr(0, stripped.length() - 3)
	return stripped.strip_edges()


static func _to_strings(values: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		out.append(str(value))
	return out
