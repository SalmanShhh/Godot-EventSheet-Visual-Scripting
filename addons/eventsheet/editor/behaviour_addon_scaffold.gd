# Godot EventSheets — "New Behaviour Addon" scaffold generator.
#
# Produces a richly-commented skeleton .gd for a custom behaviour addon. The whole point is to TEACH the
# annotation vocabulary by example: every section is commented with what it becomes (Trigger / Condition /
# Action / Expression) and the `## @ace_*` lines show the common knobs in place. Dropping the file in
# res://eventsheet_addons/ makes it an auto-discovered ACE provider — no manifest, no registration.
#
# Pure + static so it's unit-testable; the dock wraps it in a small dialog (name / base class / category)
# and writes the result to res://eventsheet_addons/<Name>/<Name>.gd.
@tool
class_name EventSheetBehaviourAddonScaffold
extends RefCounted

## Base classes offered in the New Behaviour Addon dialog. A Node-derived behaviour can be attached as a
## child of the object it acts on; a Resource is a lightweight data/helper provider. All of these support
## the `@export var` in the skeleton (a bare RefCounted does not — @export needs a Node or Resource).
const BASE_CLASSES: PackedStringArray = ["Node", "Node2D", "CharacterBody2D", "Area2D", "Resource"]

## A handful of words that can't be a class_name (would collide with the engine or break parsing).
const _RESERVED: PackedStringArray = [
	"Node", "Object", "Resource", "RefCounted", "Variant", "Signal", "Callable", "Array", "Dictionary",
	"String", "int", "float", "bool", "true", "false", "null", "self", "class", "func", "var", "const",
	"if", "else", "for", "while", "return", "match", "enum", "signal", "extends", "tool"
]

## True when `addon_name` is usable as a GDScript class_name: a plain identifier that isn't a reserved word
## and isn't already a registered global class (which would be a duplicate class_name error).
static func is_valid_class_name(addon_name: String) -> bool:
	var name: String = addon_name.strip_edges()
	if name.is_empty():
		return false
	var identifier: RegEx = RegEx.new()
	if identifier.compile("^[A-Za-z_][A-Za-z0-9_]*$") != OK or identifier.search(name) == null:
		return false
	if _RESERVED.has(name):
		return false
	if ClassDB.class_exists(name):
		return false
	# A duplicate class_name is a HARD project-wide parse error, not just a bad file — so also reject names
	# already taken by a global script class (ClassDB only knows engine classes).
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		if str(global_class.get("class", "")) == name:
			return false
	return true

## The folder + file a freshly-scaffolded addon lives in (auto-discovered by the addon scanner).
static func suggested_path(addon_name: String) -> String:
	var snake: String = _to_snake_case(addon_name)
	return "res://eventsheet_addons/%s/%s.gd" % [snake, snake]

## The richly-commented skeleton source. `category` defaults to the addon name; `description` fills the
## provider's top doc comment.
static func generate(addon_name: String, base_class: String = "Node", category: String = "", description: String = "") -> String:
	var name: String = addon_name.strip_edges()
	var base: String = base_class.strip_edges() if not base_class.strip_edges().is_empty() else "Node"
	var cat: String = _sanitize_inline(category) if not _sanitize_inline(category).is_empty() else name
	var desc: String = _sanitize_inline(description) if not _sanitize_inline(description).is_empty() else "Describe what this behaviour does in one line."
	var tag: String = _to_snake_case(name)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("@tool")
	lines.append("## %s — %s" % [name, desc])
	lines.append("## Auto-discovered: any .gd in res://eventsheet_addons/ with @tool + class_name becomes an ACE")
	lines.append("## provider. Public signals / methods / @export vars below turn into Triggers / Conditions /")
	lines.append("## Actions / Expressions automatically; the `## @ace_*` comments above each one fine-tune how")
	lines.append("## they appear in the picker. The `## @ace_*` knobs are all optional — see the examples below.")
	lines.append("##")
	lines.append("## @ace_tags(%s, custom)" % tag)
	lines.append("class_name %s" % name)
	lines.append("extends %s" % base)
	lines.append("")
	lines.append("# ── TRIGGERS — a `signal` becomes an \"On <Name>\" trigger you can start an event with. ──")
	lines.append("")
	lines.append("## @ace_name(\"On Activated\")")
	lines.append("## @ace_category(\"%s\")" % cat)
	lines.append("## @ace_description(\"Fires when this behaviour activates.\")")
	lines.append("signal activated")
	lines.append("")
	lines.append("# ── PROPERTIES — an `@export var` becomes an Expression (read it) plus Set / Add actions, and")
	lines.append("#    shows in the Godot Inspector so designers can tweak it per-instance. ──")
	lines.append("")
	lines.append("## @ace_description(\"How strong the effect is.\")")
	lines.append("@export var strength: float = 1.0")
	lines.append("")
	lines.append("# ── ACTIONS — a `func` returning void becomes an Action (a thing the event DOES). ──")
	lines.append("")
	lines.append("## @ace_action")
	lines.append("## @ace_name(\"Do The Thing\")")
	lines.append("## @ace_category(\"%s\")" % cat)
	lines.append("## @ace_description(\"Explain what running this action does, in friendly English.\")")
	lines.append("## @ace_param_hint(amount expression)   # `amount` becomes an ƒx expression box")
	lines.append("func do_the_thing(amount: float) -> void:")
	lines.append("\tstrength += amount")
	lines.append("\tactivated.emit()")
	lines.append("")
	lines.append("# ── CONDITIONS — a `func` returning bool becomes a Condition (a gate on the event). ──")
	lines.append("")
	lines.append("## @ace_condition")
	lines.append("## @ace_category(\"%s\")" % cat)
	lines.append("## @ace_description(\"True when the behaviour is at full strength.\")")
	lines.append("func is_ready() -> bool:")
	lines.append("\treturn strength >= 1.0")
	lines.append("")
	lines.append("# ── EXPRESSIONS — a `func` returning a value becomes an Expression (use it in fields). ──")
	lines.append("")
	lines.append("## @ace_expression")
	lines.append("## @ace_category(\"%s\")" % cat)
	lines.append("## @ace_description(\"The current strength value.\")")
	lines.append("func current_strength() -> float:")
	lines.append("\treturn strength")
	lines.append("")
	lines.append("# ── More knobs (all optional): ──")
	lines.append("#   ## @ace_hidden                        — hide a member from the picker")
	lines.append("#   ## @ace_deprecated(\"Use X instead\")    — keep it working but steer users to a replacement")
	lines.append("#   ## @ace_display_template(\"Set {amount} HP\")   — custom row phrasing (supports [b]/[color] BBCode)")
	lines.append("#   ## @ace_param_options(slot head, chest)        — a fixed dropdown for a param")
	lines.append("#   ## @ace_param_autocomplete(anim \"idle\", \"run\") — an editable suggestion list")
	lines.append("#   ## @ace_expose_all                     — class-level: expose EVERY public member as an ACE")
	lines.append("")
	return "\n".join(lines)

## Makes a user string safe to drop into a `## @ace_*("...")` doc-comment annotation: a newline would split
## the comment line (a parse error on the next line), and a double-quote confuses the analyzer's quote-trim
## extraction — so collapse newlines to spaces and quotes to apostrophes.
static func _sanitize_inline(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").replace("\"", "'").strip_edges()

## PascalCase / mixed → snake_case for the folder + file name. Splits only at a lowercase→Uppercase boundary
## (or before the last capital of an acronym that starts a word), so "HUDManager" → "hud_manager",
## "ABCWidget" → "abc_widget", "Box2D" → "box2d" — not "h_u_d_manager". Collapses repeats; trims edges.
static func _to_snake_case(text: String) -> String:
	var cleaned: String = text.strip_edges().replace(" ", "_").replace("-", "_")
	var out: String = ""
	for i in range(cleaned.length()):
		var c: String = cleaned[i]
		var is_upper: bool = c != c.to_lower() and c == c.to_upper()
		if is_upper and i > 0:
			var prev: String = cleaned[i - 1]
			var prev_is_lower_letter: bool = prev != "_" and prev == prev.to_lower() and prev != prev.to_upper()
			var next_is_lower_letter: bool = i + 1 < cleaned.length() and cleaned[i + 1] == cleaned[i + 1].to_lower() and cleaned[i + 1] != cleaned[i + 1].to_upper()
			if (prev_is_lower_letter or next_is_lower_letter) and not out.ends_with("_"):
				out += "_"
		out += c.to_lower()
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")
