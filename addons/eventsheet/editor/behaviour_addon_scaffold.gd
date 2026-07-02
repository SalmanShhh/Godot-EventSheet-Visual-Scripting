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

## The starter recipes the New Behaviour dialog offers. Order is index-stable (the dialog's
## OptionButton and the tests read by index). "skeleton" is the teaching default; the others are
## small, complete, game-shaped behaviours with every verb annotated — a working example beats a
## commented placeholder once someone has seen the skeleton once.
const RECIPES: Array[Dictionary] = [
	{"id": "skeleton", "label": "Teaching skeleton — one of each kind, heavily commented"},
	{"id": "cooldown", "label": "Cooldown — an ability timer (start · is ready · time left)"},
	{"id": "stat_pool", "label": "Stat pool — a bounded value (spend · restore · percent)"},
]

## Dispatches to the chosen recipe's generator (falls back to the teaching skeleton).
static func generate_recipe(recipe_id: String, addon_name: String, base_class: String = "Node", category: String = "", description: String = "") -> String:
	match recipe_id:
		"cooldown":
			return generate_cooldown(addon_name, base_class, category, description)
		"stat_pool":
			return generate_stat_pool(addon_name, base_class, category, description)
		_:
			return generate(addon_name, base_class, category, description)

## A complete ability-cooldown behaviour: start it, gate events on readiness, read the remaining
## time. Counts down in _process (so a Node-derived base is the natural fit — the dialog defaults
## there); every public member carries its picker annotations, so it opens code-free immediately.
static func generate_cooldown(addon_name: String, base_class: String = "Node", category: String = "", description: String = "") -> String:
	var name: String = addon_name.strip_edges()
	var base: String = base_class.strip_edges() if not base_class.strip_edges().is_empty() else "Node"
	var cat: String = _sanitize_inline(category) if not _sanitize_inline(category).is_empty() else name
	var desc: String = _sanitize_inline(description) if not _sanitize_inline(description).is_empty() else "An ability cooldown: start it, check it, read the time left."
	return "\n".join(PackedStringArray([
		"@tool",
		"## %s — %s" % [name, desc],
		"## @ace_tags(%s, custom)" % _to_snake_case(name),
		"class_name %s" % name,
		"extends %s" % base,
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cooldown Finished\")",
		"## @ace_category(\"%s\")" % cat,
		"signal cooldown_finished",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cooldown Started\")",
		"## @ace_category(\"%s\")" % cat,
		"signal cooldown_started",
		"",
		"## @ace_description(\"Seconds a full cooldown takes.\")",
		"@export var duration: float = 1.5",
		"",
		"var _time_left: float = 0.0",
		"",
		"func _process(delta: float) -> void:",
		"\tif _time_left > 0.0:",
		"\t\t_time_left = maxf(_time_left - delta, 0.0)",
		"\t\tif _time_left == 0.0:",
		"\t\t\tcooldown_finished.emit()",
		"",
		"## @ace_action",
		"## @ace_name(\"Start Cooldown\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Begins a full cooldown (restarts it if already running).\")",
		"func start() -> void:",
		"\t_time_left = duration",
		"\tcooldown_started.emit()",
		"",
		"## @ace_action",
		"## @ace_name(\"Reset Cooldown\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Clears the cooldown so the ability is immediately ready.\")",
		"func reset() -> void:",
		"\t_time_left = 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Ready\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"True when the cooldown is not running.\")",
		"func is_ready() -> bool:",
		"\treturn _time_left <= 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Cooling Down\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"True while the cooldown is still counting.\")",
		"func is_cooling_down() -> bool:",
		"\treturn _time_left > 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Time Left\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Seconds remaining until ready (0 when ready).\")",
		"func time_left() -> float:",
		"\treturn _time_left",
		"",
		"## @ace_expression",
		"## @ace_name(\"Cooldown Progress\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"How far through the cooldown we are, 0.0 (just started) to 1.0 (ready).\")",
		"func progress() -> float:",
		"\treturn 1.0 - (_time_left / duration) if duration > 0.0 else 1.0",
		"",
	]))

## A complete bounded-stat behaviour (health, mana, stamina, ammo…): spend it, restore it, gate on
## empty/full, read the percentage. Every public member carries its picker annotations.
static func generate_stat_pool(addon_name: String, base_class: String = "Node", category: String = "", description: String = "") -> String:
	var name: String = addon_name.strip_edges()
	var base: String = base_class.strip_edges() if not base_class.strip_edges().is_empty() else "Node"
	var cat: String = _sanitize_inline(category) if not _sanitize_inline(category).is_empty() else name
	var desc: String = _sanitize_inline(description) if not _sanitize_inline(description).is_empty() else "A bounded value: spend it, restore it, watch it empty."
	return "\n".join(PackedStringArray([
		"@tool",
		"## %s — %s" % [name, desc],
		"## @ace_tags(%s, custom)" % _to_snake_case(name),
		"class_name %s" % name,
		"extends %s" % base,
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Depleted\")",
		"## @ace_category(\"%s\")" % cat,
		"signal depleted",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Value Changed\")",
		"## @ace_category(\"%s\")" % cat,
		"signal value_changed",
		"",
		"## @ace_description(\"The largest value the pool can hold.\")",
		"@export var max_value: float = 100.0",
		"",
		"var _value: float = 100.0",
		"",
		"## @ace_action",
		"## @ace_name(\"Spend\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Removes an amount (clamped at zero; fires On Depleted when it empties).\")",
		"func spend(amount: float) -> void:",
		"\tif amount <= 0.0 or _value <= 0.0:",
		"\t\treturn",
		"\t_value = maxf(_value - amount, 0.0)",
		"\tvalue_changed.emit()",
		"\tif _value == 0.0:",
		"\t\tdepleted.emit()",
		"",
		"## @ace_action",
		"## @ace_name(\"Restore\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Adds an amount back (clamped at the maximum).\")",
		"func restore(amount: float) -> void:",
		"\tif amount <= 0.0:",
		"\t\treturn",
		"\t_value = minf(_value + amount, max_value)",
		"\tvalue_changed.emit()",
		"",
		"## @ace_action",
		"## @ace_name(\"Refill\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"Sets the value back to the maximum.\")",
		"func refill() -> void:",
		"\t_value = max_value",
		"\tvalue_changed.emit()",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Empty\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"True when the value is zero.\")",
		"func is_empty() -> bool:",
		"\treturn _value <= 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Full\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"True when the value is at its maximum.\")",
		"func is_full() -> bool:",
		"\treturn _value >= max_value",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Value\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"The value right now.\")",
		"func current_value() -> float:",
		"\treturn _value",
		"",
		"## @ace_expression",
		"## @ace_name(\"Percent\")",
		"## @ace_category(\"%s\")" % cat,
		"## @ace_description(\"How full the pool is, 0.0 to 1.0.\")",
		"func percent() -> float:",
		"\treturn _value / max_value if max_value > 0.0 else 0.0",
		"",
	]))

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
