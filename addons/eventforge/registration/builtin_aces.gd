# EventForge — Built-in ACE registry
# AUTO-DISCOVERS the per-vocabulary modules in registration/modules/: any script there that exposes
# `static func get_descriptors() -> Array[ACEDescriptor]` is loaded and concatenated automatically, so
# adding a module is just dropping a file (no edit here). See ace_factory.gd for the module contract;
# ace_ids/templates are API (compatibility covenant: hide with @ace_hidden, never rename).
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

const COMPARISON_OPERATORS: Array[String] = EventForgeACEFactory.COMPARISON_OPERATORS
const MODULES_DIR := "res://addons/eventforge/registration/modules/"

## Every built-in descriptor, auto-discovered from registration/modules/. Drop a module file there
## (a script with `static func get_descriptors() -> Array[ACEDescriptor]`) and its ACEs register on
## the next load — no wiring here. Files load in a stable sorted order with the generic helper_aces
## module forced LAST, so its catch-all templates never shadow a specific ACE in the reverse-lifter.
## (Order otherwise does not affect compiled output: each ACE compiles independently, the picker
## groups by category, and the lifter sorts entries by specificity.)
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for module_file: String in _module_files():
		var script: GDScript = load(MODULES_DIR + module_file)
		if script == null or not _has_get_descriptors(script):
			continue
		var module_descriptors: Variant = script.call("get_descriptors")
		if module_descriptors is Array:
			for entry: Variant in module_descriptors:
				if entry is ACEDescriptor:
					descriptors.append(entry)
	# Cross-node: give every host-only node-scoped ACE an optional "On node" target so it can act on
	# another node, not just the host. Covenant-safe — a blank target compiles to the original host
	# call, byte-for-byte (see _make_node_scoped_targetable + the {target.} idiom in ActionCodegen).
	for descriptor: ACEDescriptor in descriptors:
		_make_node_scoped_targetable(descriptor)
	return descriptors

## GDScript keywords that can lead a statement: a template line starting with one is control flow, not
## a member operation, so it can never be safely prefixed with another node.
const _STATEMENT_KEYWORDS: PackedStringArray = ["if", "elif", "else", "for", "while", "var", "const", "return", "match", "await", "pass", "break", "continue"]

## In place: if `descriptor` is a host-only node-scoped ACE whose template is a simple member operation,
## prepend the optional-prefix `{target.}` to each line and append an optional "On node" target param.
## Left blank the descriptor compiles exactly as before (acting on the host); set it and the whole
## operation retargets to another node. Skips triggers, templateless ACEs, ACEs that already own a
## "target" param (e.g. the Joint body setters), and templates that are not safe to prefix.
static func _make_node_scoped_targetable(descriptor: ACEDescriptor) -> void:
	if str(descriptor.node_type).is_empty():
		return
	if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
		return
	var template: String = str(descriptor.codegen_template)
	if template.strip_edges().is_empty():
		return
	for param: ACEParam in descriptor.params:
		if str(param.id) == "target":
			return  # already carries its own target semantics
	if not _is_target_prefixable(template):
		return
	var out: PackedStringArray = PackedStringArray()
	for line: String in template.split("\n"):
		if line.strip_edges().is_empty():
			out.append(line)
			continue
		var lead_len: int = line.length() - line.lstrip(" \t").length()
		out.append(line.substr(0, lead_len) + "{target.}" + line.substr(lead_len))
	descriptor.codegen_template = "\n".join(out)
	descriptor.params.append(EventForgeACEFactory.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, or pick a node / type a path like $Enemy or get_node(\"UI/Score\").", "expression"))

## True when every non-blank template line is a simple member operation that survives a `<node>.` prefix
## — a method call or an assignment whose right-hand side does not read the assigned member back. Lines
## leading with a statement keyword, `@`, `$`, `%` or a non-identifier are rejected (the spawn-a-new-node
## templates), as are self-referential assignments, so retargeting can never silently fold the host's
## own state into another node.
static func _is_target_prefixable(template: String) -> bool:
	for line: String in template.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue
		var first: String = trimmed.substr(0, 1)
		if not (first == "_" or first.to_lower() != first.to_upper()):
			return false  # must start with an identifier (letter or underscore)
		var head_word: String = trimmed.split("(")[0].split(" ")[0].split(".")[0].split("=")[0].strip_edges()
		if _STATEMENT_KEYWORDS.has(head_word):
			return false
		if not _assignment_rhs_is_target_safe(trimmed):
			return false
	return true

## For an assignment line, true when the assigned member is not read back on the right-hand side
## (ignoring `{param}` placeholders, which are values, not the host member, so `value = {value}` is
## safe). Comparison lines (`==`, `!=`, `<=`, `>=`) and bare method calls are always safe.
static func _assignment_rhs_is_target_safe(line: String) -> bool:
	var equals: int = line.find("=")
	if equals < 0:
		return true  # method call / no assignment
	var before: String = line.substr(0, equals).strip_edges()
	if before.is_empty() or before.ends_with("!") or before.ends_with("<") or before.ends_with(">"):
		return true  # a comparison, not an assignment
	if equals + 1 < line.length() and line[equals + 1] == "=":
		return true  # `==` comparison
	var member: String = before.split(" ")[0].rstrip("+-*/%")  # drop a compound-assign operator
	if member.is_empty():
		return true
	var placeholder_re: RegEx = RegEx.new()
	placeholder_re.compile("\\{[^}]*\\}")
	var rhs: String = placeholder_re.sub(line.substr(equals + 1), " ", true)
	var word_re: RegEx = RegEx.new()
	word_re.compile("\\b" + member + "\\b")
	return word_re.search(rhs) == null

## The module .gd files in a stable order: sorted alphabetically, with helper_aces.gd appended last.
static func _module_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var helpers: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(MODULES_DIR):
		if not file.ends_with(".gd"):
			continue  # skips the .gd.uid sidecars too
		if file == "helper_aces.gd":
			helpers.append(file)
		else:
			files.append(file)
	files.sort()
	files.append_array(helpers)
	return files

## True when the loaded script declares a get_descriptors method (the module contract).
static func _has_get_descriptors(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "get_descriptors":
			return true
	return false

# ── Legacy helper API (kept for external callers; the modules use the factory) ──

static func _input_action_options() -> Array[String]:
	return EventForgeACEFactory.input_action_options()

static func _default_input_action() -> String:
	return EventForgeACEFactory.default_input_action()

static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
	return EventForgeACEFactory.make_descriptor(provider_id, ace_id, display_name, ace_type, codegen_template, signal_name, params, category, display_text, node_type)

static func _make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array[String] = []) -> ACEParam:
	return EventForgeACEFactory.make_param(param_id, type_name, default_value, display_name, description, hint, options)
