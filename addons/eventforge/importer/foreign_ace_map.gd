# EventForge - the vocabulary map for sheets exported from another event-sheet editor
#
# One table, two directions of honesty. ROWS maps a foreign (object kind, row id) pair onto a
# shipped ACE and says how each of that ACE's parameters is filled; ADOPTABLE names the behaviour
# pack that already covers a foreign behaviour the free vocabulary cannot spell, so a row nobody
# can map still gets a sentence a reader can act on ("attach the Bullet pack") instead of silence.
#
# Every ace_id here was checked against the shipped registry (ACERegistry.find_descriptor) and
# every parameter id against that descriptor's own params, by the test that ships beside this file -
# so a renamed parameter fails the suite instead of quietly writing a row nobody can compile.
#
# Parameter sources, the little language the `params` dictionaries speak:
#   "#Name"  take the foreign parameter called Name, through the expression translator
#   "!Name"  take the foreign parameter called Name VERBATIM and FLAG it as untranslated
#   "~Name"  a KEY name, through the key table
#   "^Name"  a mouse BUTTON name, through the button table
#   "=Name"  a COMPARISON, through the comparison table
#   "@node"  the node the object was mapped to ("" = the sheet's own host)
#   "@self"  the same, but `self` when nothing was mapped (for slots that need a real node)
#   "@name"  the object's own name as a variable name (a list object IS the list)
#   "%f|a|b" a format string filled from the sources after it
#   "$text"  a literal
#
# Nothing in this file names the other editor: the ids below are the ids that editor's own export
# writes, and they are data, the same way a file extension is.
@tool
class_name EventSheetForeignACEMap
extends RefCounted

## Row kinds a mapping entry can produce.
const KIND_CONDITION: String = "condition"
const KIND_ACTION: String = "action"
const KIND_TRIGGER: String = "trigger"

## The object kinds that stand for a whole plugin rather than a placed object: their name in the
## export IS the plugin's name, so they need no entry in the wizard's object table.
const SYSTEM_OBJECT_KINDS: Array[String] = [
	"System", "Keyboard", "Mouse", "Touch", "Browser", "Audio", "Array", "Dictionary",
	"JSON", "Functions", "AJAX", "LocalStorage",
]

## The object kinds an entry in the wizard's mapping table can be given. "Object" is the generic
## fallback every placed object answers to (instance variables, destroy, visibility).
const PLACED_OBJECT_KINDS: Array[String] = [
	"Object", "Sprite", "Text", "Audio", "Timer", "TiledBackground", "NinePatch", "Particles",
]

## (kind, row id) -> the shipped row it becomes.
##
## Keys are "<kind>/<id>" with the id normalised (lower case, dashes). Values carry:
##   ace      the shipped ace_id, provider "Core"
##   kind     condition / action / trigger
##   trigger  when a CONDITION only makes sense inside a run context, the trigger to open (the
##            input events are conditions on the input trigger, exactly as a hand-written sheet
##            spells them)
##   params   ace parameter id -> a source from the little language above
##   note     an honest caveat recorded on the row and in the report
const ROWS: Dictionary = {
	# --- the sheet's own engine ------------------------------------------------------------
	"System/every-tick": {"ace": "OnProcess", "kind": KIND_TRIGGER},
	"System/on-start-of-layout": {"ace": "OnReady", "kind": KIND_TRIGGER},
	"System/on-end-of-layout": {"ace": "OnExitTree", "kind": KIND_TRIGGER},
	"System/trigger-once-while-true": {"ace": "TriggerOnce", "kind": KIND_CONDITION},
	"System/every-x-seconds": {"ace": "EveryXSeconds", "kind": KIND_CONDITION, "params": {"seconds": "#Interval"}},
	"System/compare-variable": {"ace": "CompareVar", "kind": KIND_CONDITION, "params": {"var_name": "#Variable", "op": "=Comparison", "value": "#Value"}},
	"System/compare-two-values": {"ace": "CompareValues", "kind": KIND_CONDITION, "params": {"a": "#First value", "op": "=Comparison", "b": "#Second value"}},
	"System/is-between-values": {"ace": "IsBetween", "kind": KIND_CONDITION, "params": {"value": "#Value", "min": "#Lower bound", "max": "#Upper bound"}},
	"System/set-value": {"ace": "SetVar", "kind": KIND_ACTION, "params": {"var_name": "#Variable", "value": "#Value"}},
	"System/add-to": {"ace": "AddVar", "kind": KIND_ACTION, "params": {"var_name": "#Variable", "amount": "#Value"}},
	"System/subtract-from": {"ace": "SubtractVar", "kind": KIND_ACTION, "params": {"var_name": "#Variable", "amount": "#Value"}},
	"System/toggle-boolean": {"ace": "ToggleVar", "kind": KIND_ACTION, "params": {"var_name": "#Variable"}},
	"System/wait": {"ace": "Wait", "kind": KIND_ACTION, "params": {"seconds": "#Seconds"}},
	"System/go-to-layout": {"ace": "ChangeScene", "kind": KIND_ACTION, "params": {"path": "!Layout"}, "note": "The layout name is kept as written - point it at the scene file that replaced that layout."},
	"System/restart-layout": {"ace": "ReloadScene", "kind": KIND_ACTION},
	"System/create-object": {"ace": "SpawnScene", "kind": KIND_ACTION, "params": {"path": "!Object to create"}, "note": "The object name is kept as written - point it at the scene file that object became."},
	"System/set-timescale": {"ace": "SetTimeScale", "kind": KIND_ACTION, "params": {"scale": "#Time scale"}},
	"System/set-paused": {"ace": "SetPaused", "kind": KIND_ACTION, "params": {"paused": "#Paused"}},
	"System/set-canvas-size": {"ace": "PrintLog", "kind": KIND_ACTION, "params": {"message": "$\"TODO: set the window size\""}, "note": "Window size is a project setting here, not a row."},
	"Browser/log": {"ace": "PrintLog", "kind": KIND_ACTION, "params": {"message": "#Message"}},
	"Browser/close": {"ace": "QuitGame", "kind": KIND_ACTION},

	# --- input ------------------------------------------------------------------------------
	"Keyboard/on-key-pressed": {"ace": "KeyEventPressed", "kind": KIND_CONDITION, "trigger": "OnInput", "params": {"key": "~Key"}},
	"Keyboard/on-key-released": {"ace": "KeyEventReleased", "kind": KIND_CONDITION, "trigger": "OnInput", "params": {"key": "~Key"}},
	"Keyboard/key-is-down": {"ace": "KeyIsDown", "kind": KIND_CONDITION, "params": {"key": "~Key"}},
	"Mouse/on-click": {"ace": "MouseButtonEventPressed", "kind": KIND_CONDITION, "trigger": "OnInput", "params": {"button": "^Button"}},
	"Mouse/on-any-click": {"ace": "MouseButtonEventPressed", "kind": KIND_CONDITION, "trigger": "OnInput"},
	"Mouse/mouse-button-is-down": {"ace": "MouseButtonDown", "kind": KIND_CONDITION, "params": {"button": "^Button"}},
	"Touch/on-touch-start": {"ace": "TouchEventPressed", "kind": KIND_CONDITION, "trigger": "OnInput"},
	"Touch/on-touch-end": {"ace": "TouchEventReleased", "kind": KIND_CONDITION, "trigger": "OnInput"},
	"Touch/is-touching-object": {"ace": "TouchEventPressed", "kind": KIND_CONDITION, "trigger": "OnInput", "note": "Which object was touched is not carried over - add the object check yourself."},

	# --- every placed object ----------------------------------------------------------------
	"Object/compare-instance-variable": {"ace": "CompareVar", "kind": KIND_CONDITION, "params": {"var_name": "#Instance variable", "op": "=Comparison", "value": "#Value"}},
	"Object/is-boolean-instance-variable-set": {"ace": "CompareVar", "kind": KIND_CONDITION, "params": {"var_name": "#Instance variable", "op": "$==", "value": "$true"}},
	"Object/set-value": {"ace": "SetVar", "kind": KIND_ACTION, "params": {"var_name": "#Instance variable", "value": "#Value"}},
	"Object/add-to-value": {"ace": "AddVar", "kind": KIND_ACTION, "params": {"var_name": "#Instance variable", "amount": "#Value"}},
	"Object/subtract-from-value": {"ace": "SubtractVar", "kind": KIND_ACTION, "params": {"var_name": "#Instance variable", "amount": "#Value"}},
	"Object/toggle-boolean": {"ace": "ToggleVar", "kind": KIND_ACTION, "params": {"var_name": "#Instance variable"}},
	"Object/destroy": {"ace": "QueueFreeNode", "kind": KIND_ACTION, "params": {"target": "@self"}},
	"Object/is-visible": {"ace": "IsVisible", "kind": KIND_CONDITION, "params": {"target": "@node"}},
	"Object/set-visible": {"ace": "ShowNode", "kind": KIND_ACTION, "params": {"target": "@node"}, "note": "Set-visible always becomes Show here - add a Hide row where the value was false."},
	"Object/is-on-screen": {"ace": "IsOnScreen", "kind": KIND_CONDITION, "params": {"target": "@node"}},
	"Object/is-outside-layout": {"ace": "IsOutsideLayout", "kind": KIND_CONDITION},
	"Object/is-overlapping-another-object": {"ace": "HasOverlappingBodies", "kind": KIND_CONDITION, "params": {"target": "@node"}, "note": "Which object it overlaps is not carried over - narrow it with a group check."},
	"Object/is-in-group": {"ace": "IsInGroup", "kind": KIND_CONDITION, "params": {"target": "@self", "group": "#Family"}},
	"Object/add-to-group": {"ace": "AddToGroup", "kind": KIND_ACTION, "params": {"target": "@self", "group": "#Family"}},

	# --- sprites ----------------------------------------------------------------------------
	"Sprite/set-position": {"ace": "SetPosition2D", "kind": KIND_ACTION, "params": {"target": "@node", "pos": "%Vector2(%s, %s)|#X|#Y"}},
	"Sprite/move-at-angle": {"ace": "MoveBy2D", "kind": KIND_ACTION, "params": {"target": "@node", "offset": "%Vector2.RIGHT.rotated(deg_to_rad(%s)) * %s|#Angle|#Distance"}},
	"Sprite/set-angle": {"ace": "SetRotationDeg", "kind": KIND_ACTION, "params": {"target": "@node", "degrees": "#Angle"}},
	"Sprite/set-animation": {"ace": "PlaySpriteAnimation", "kind": KIND_ACTION, "params": {"target": "@node", "anim": "#Animation"}},
	"Sprite/set-animation-frame": {"ace": "SetSpriteFrame", "kind": KIND_ACTION, "params": {"target": "@node", "frame": "#Frame number"}},
	"Sprite/is-animation-playing": {"ace": "IsSpriteAnimationPlaying", "kind": KIND_CONDITION, "params": {"target": "@node"}},
	"Sprite/set-mirrored": {"ace": "SetFlipH", "kind": KIND_ACTION, "params": {"target": "@node", "flipped": "#State"}},
	"Sprite/set-opacity": {"ace": "SetModulate", "kind": KIND_ACTION, "params": {"target": "@node", "color": "%Color(1, 1, 1, %s)|!Opacity"}, "note": "Opacity was a percentage - divide it by 100."},
	"Sprite/set-color": {"ace": "SetModulate", "kind": KIND_ACTION, "params": {"target": "@node", "color": "!Color"}},

	# --- text -------------------------------------------------------------------------------
	"Text/set-text": {"ace": "SetLabelText", "kind": KIND_ACTION, "params": {"target": "@node", "value": "#Text"}},
	"Text/append-text": {"ace": "AppendLabelText", "kind": KIND_ACTION, "params": {"target": "@node", "value": "#Text"}},

	# --- audio ------------------------------------------------------------------------------
	"Audio/play": {"ace": "PlaySound", "kind": KIND_ACTION, "params": {"path": "!Audio file"}, "note": "The audio file is kept as written - point it at the imported sound."},
	"Audio/stop-all": {"ace": "StopLastSound", "kind": KIND_ACTION},
	"Audio/set-volume": {"ace": "SetBusVolume", "kind": KIND_ACTION, "params": {"bus": "$\"Master\"", "db": "#Volume"}},

	# --- lists and records ------------------------------------------------------------------
	"Array/push": {"ace": "ArrayAppend", "kind": KIND_ACTION, "params": {"var_name": "@name", "value": "#Value"}},
	"Array/clear": {"ace": "ArrayClear", "kind": KIND_ACTION, "params": {"var_name": "@name"}},
	"Array/contains-value": {"ace": "ArrayContains", "kind": KIND_CONDITION, "params": {"var_name": "@name", "value": "#Value"}},
	"Dictionary/set-key": {"ace": "DictSetKey", "kind": KIND_ACTION, "params": {"var_name": "@name", "key": "#Key", "value": "#Value"}},
	"Dictionary/delete-key": {"ace": "DictDeleteKey", "kind": KIND_ACTION, "params": {"var_name": "@name", "key": "#Key"}},
	"Dictionary/has-key": {"ace": "DictHasKey", "kind": KIND_CONDITION, "params": {"var_name": "@name", "key": "#Key"}},
	"JSON/parse": {"ace": "JsonParseToVar", "kind": KIND_ACTION, "params": {"var_name": "@name", "text": "#JSON string"}},

	# --- functions --------------------------------------------------------------------------
	"Functions/call-function": {"ace": "CallFunction", "kind": KIND_ACTION, "params": {"function_name": "#Name", "args": "#Parameters"}},
	"Functions/set-return-value": {"ace": "ReturnValue", "kind": KIND_ACTION, "params": {"value": "#Value"}},
}

## Foreign behaviours whose shape a shipped behaviour pack already covers. A row on one of these
## cannot be mapped honestly (the free vocabulary has no single sentence for it), so the importer
## disables the row and the report says which pack to attach instead.
const ADOPTABLE: Dictionary = {
	"bullet": {"pack": "bullet", "words": "Bullet"},
	"platform": {"pack": "platformer_movement", "words": "Platformer Movement"},
	"8direction": {"pack": "eight_direction", "words": "8-Direction"},
	"eightdirection": {"pack": "eight_direction", "words": "8-Direction"},
	"timer": {"pack": "timer", "words": "Timer"},
	"tween": {"pack": "tween", "words": "Tween"},
	"sine": {"pack": "sine", "words": "Sine"},
	"fade": {"pack": "fade", "words": "Fade"},
	"flash": {"pack": "flash", "words": "Flash"},
	"pathfinding": {"pack": "platformer_pathfinding", "words": "Platformer Pathfinding"},
	"lineofsight": {"pack": "line_of_sight", "words": "Line Of Sight"},
	"dragdrop": {"pack": "drag_drop", "words": "Drag And Drop"},
	"moveto": {"pack": "move_to", "words": "Move To"},
	"rotate": {"pack": "rotate", "words": "Rotate"},
	"wrap": {"pack": "wrap", "words": "Wrap"},
	"boundtolayout": {"pack": "bound_to", "words": "Bound To Layout"},
	"statemachine": {"pack": "state_machine", "words": "State Machine"},
	"localstorage": {"pack": "save_system", "words": "Save System"},
}

## The behaviour rows a shipped pack cannot spell either, with the honest reason.
const NO_HOME: Dictionary = {
	"ajax": "Nothing here speaks HTTP yet - write the request as a script block.",
	"multiplayer": "Multiplayer here is Godot's own, not a row-for-row twin.",
}

## The properties a placed object answers to, in both vocabularies. Used to rewrite `Player.X`
## into the node property it means, so an imported expression names something that exists.
const OBJECT_PROPERTIES: Dictionary = {
	"X": "position.x",
	"Y": "position.y",
	"Angle": "rotation_degrees",
	"Text": "text",
	"Opacity": "modulate.a",
	"AnimationFrame": "frame",
	"Visible": "visible",
}

## Key names, in both vocabularies. Anything not here is kept as written and flagged, because a key
## nobody can name is a key nobody can press.
const KEY_NAMES: Dictionary = {
	"space": "KEY_SPACE", "enter": "KEY_ENTER", "return": "KEY_ENTER", "esc": "KEY_ESCAPE",
	"escape": "KEY_ESCAPE", "tab": "KEY_TAB", "shift": "KEY_SHIFT", "control": "KEY_CTRL",
	"ctrl": "KEY_CTRL", "alt": "KEY_ALT", "backspace": "KEY_BACKSPACE", "delete": "KEY_DELETE",
	"up": "KEY_UP", "down": "KEY_DOWN", "left": "KEY_LEFT", "right": "KEY_RIGHT",
	"up arrow": "KEY_UP", "down arrow": "KEY_DOWN", "left arrow": "KEY_LEFT",
	"right arrow": "KEY_RIGHT", "home": "KEY_HOME", "end": "KEY_END",
}

## Comparisons, in both vocabularies. The export writes a comparison either as the symbol a reader
## sees or as its place in the drop-down (0 = equal, then not-equal, less, less-or-equal, greater,
## greater-or-equal), and the two spellings that matter most - a single `=` for equality and `<>`
## for inequality - are ASSIGNMENT and nothing at all in GDScript. Left as written they wrote a file
## that does not parse, so every comparison goes through here and one nobody can name is refused.
const COMPARISON_OPERATORS: Dictionary = {
	"=": "==", "==": "==", "0": "==",
	"≠": "!=", "<>": "!=", "!=": "!=", "1": "!=",
	"<": "<", "2": "<",
	"≤": "<=", "<=": "<=", "3": "<=",
	">": ">", "4": ">",
	"≥": ">=", ">=": ">=", "5": ">=",
}

## Mouse button names, in both vocabularies.
const BUTTON_NAMES: Dictionary = {
	"left": "MOUSE_BUTTON_LEFT", "right": "MOUSE_BUTTON_RIGHT", "middle": "MOUSE_BUTTON_MIDDLE",
	"0": "MOUSE_BUTTON_LEFT", "1": "MOUSE_BUTTON_MIDDLE", "2": "MOUSE_BUTTON_RIGHT",
}


## The sheet's expression names, back into GDScript.
##
## This is the exact INVERSE of the reading layer's familiar-expression table: the words a reader
## types on one side, the calls the compiler emits on the other. Reading and importing therefore
## agree by construction - a `random(1, 6)` that arrives here becomes the very call the reading
## would turn back into `random(1, 6)`.
##
## `lerp`, `clamp`, `abs`, `floor`, `ceil`, `round`, `sqrt`, `min` and `max` are absent on purpose:
## both vocabularies spell those the same, so there is nothing to rewrite.
const EXPRESSION_PATTERNS: Array = [
	["\\bdistance\\(([^(),]+),\\s*([^(),]+)\\)", "$1.position.distance_to($2.position)"],
	["\\bangle\\(([^(),]+),\\s*([^(),]+)\\)", "$1.get_angle_to($2.position)"],
	["\\btokenat\\(([^(),]+),\\s*([^(),]+),\\s*([^(),]+)\\)", "$1.split($3)[$2]"],
	["\\bzeropad\\(([^(),]+),\\s*([0-9]+)\\)", "\"%0$2d\" % $1"],
	["\\bleft\\(([^(),]+),\\s*([^(),]+)\\)", "$1.substr(0, $2)"],
	["\\bmid\\(([^(),]+),\\s*([^(),]+),\\s*([^(),]+)\\)", "$1.substr($2, $3)"],
	["\\blen\\(([^(),]+)\\)", "$1.length()"],
	["\\btickcount\\b", "Engine.get_process_frames()"],
	["\\bchoose\\(([^()]+)\\)", "[$1].pick_random()"],
	["\\brandom\\(([^(),]+),\\s*([^(),]+)\\)", "randf_range($1, $2)"],
	["\\brandom\\(([^(),]+)\\)", "randf_range(0.0, $1)"],
	["\\bdt\\b", "delta"],
	["\\bloopindex\\b", "index"],
	["\\bint\\(([^()]+)\\)", "int($1)"],
	["\\bfloat\\(([^()]+)\\)", "float($1)"],
	["\\bstr\\(([^()]+)\\)", "str($1)"],
	["\\buppercase\\(([^()]+)\\)", "$1.to_upper()"],
	["\\blowercase\\(([^()]+)\\)", "$1.to_lower()"],
	["\\bfind\\(([^(),]+),\\s*([^(),]+)\\)", "$1.find($2)"],
	["\\bnewline\\b", "\"\\n\""],
]

## Foreign shapes that survive translation and mean the value still needs a human. Kept separate
## from the table above so the flag can never drift from the rewriting.
const RESIDUAL_PATTERNS: Array = [
	"[A-Za-z_][A-Za-z0-9_]*\\.[A-Z][A-Za-z0-9_]*",
	"&",
	# A call in a name the table above DOES rewrite, still standing after every rewrite ran, is one
	# the table met at an arity it does not know - `distance(x1, y1, x2, y2)` beside the two-argument
	# form, say. Nothing here spells it, so it is flagged rather than written out as a call to a
	# function that does not exist. The names are the table's own, so the two can never drift apart.
	"\\b(distance|angle|tokenat|zeropad|left|mid|len|choose|random|find|uppercase|lowercase)\\s*\\(",
]

static var _compiled_expressions: Array = []
static var _compiled_residuals: Array = []


## The lookup key for a row: the object kind and the row id, both normalised.
static func row_key(object_kind: String, row_id: String) -> String:
	return "%s/%s" % [object_kind.strip_edges(), normalize_id(row_id)]


## A foreign row id in the one spelling this table uses: lower case, dashes between words.
static func normalize_id(row_id: String) -> String:
	var out: String = row_id.strip_edges().to_lower()
	out = out.replace("_", "-").replace(" ", "-")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out


## A behaviour name in the one spelling ADOPTABLE / NO_HOME use: letters only, lower case.
static func normalize_behavior(behavior: String) -> String:
	var out: String = ""
	for character: String in behavior.to_lower():
		if character >= "a" and character <= "z":
			out += character
	return out


## The mapping for a row, or an empty dictionary when the vocabulary has no word for it. Placed
## objects fall back to the generic "Object" entries, which is where instance variables live.
static func lookup(object_kind: String, row_id: String) -> Dictionary:
	var direct: Variant = ROWS.get(row_key(object_kind, row_id), {})
	if not (direct as Dictionary).is_empty():
		return direct
	if SYSTEM_OBJECT_KINDS.has(object_kind):
		return {}
	return ROWS.get(row_key("Object", row_id), {})


## A key name in the words the export wrote, as the Godot constant it means.
## Returns {"text": String, "translated": bool}.
static func translate_key(name: String) -> Dictionary:
	return _from_table(name, KEY_NAMES, "KEY_")


## A mouse button name in the words the export wrote, as the Godot constant it means.
static func translate_button(name: String) -> Dictionary:
	return _from_table(name, BUTTON_NAMES, "MOUSE_BUTTON_")


## A comparison in the words (or the drop-down place) the export wrote, as the GDScript operator it
## means. Returns {"text": String, "translated": bool}; translated false means the row cannot be
## built honestly, because a comparison nobody can name is a condition nobody can run.
static func translate_comparison(name: String) -> Dictionary:
	var trimmed: String = name.strip_edges()
	if COMPARISON_OPERATORS.has(trimmed):
		return {"text": str(COMPARISON_OPERATORS[trimmed]), "translated": true}
	return {"text": trimmed, "translated": false}


static func _from_table(name: String, table: Dictionary, already: String) -> Dictionary:
	var trimmed: String = name.strip_edges()
	if trimmed.begins_with(already):
		return {"text": trimmed, "translated": true}
	var lowered: String = trimmed.to_lower()
	if table.has(lowered):
		return {"text": str(table[lowered]), "translated": true}
	# A single letter or digit IS its own key name. Only for the key table, though: a mouse button
	# nobody can name is kept as written rather than handed a keyboard constant, which would put a
	# `KEY_3` in a slot that asks which button was clicked.
	if already == "KEY_" and lowered.length() == 1 and ((lowered >= "a" and lowered <= "z") or (lowered >= "0" and lowered <= "9")):
		return {"text": "KEY_%s" % lowered.to_upper(), "translated": true}
	return {"text": trimmed, "translated": false}


## Every name the sheet declares, from its own spelling to the one the generated file uses, plus the
## object properties that have a node property behind them. Handed to translate_expression so an
## imported value names something that exists in the file it lands in.
static func value_aliases(declared: Dictionary, objects: Dictionary) -> Dictionary:
	var aliases: Dictionary = {}
	for object_name: String in objects:
		var node: String = str((objects[object_name] as Dictionary).get("node", "")).strip_edges()
		if node.is_empty():
			continue
		for property_name: String in OBJECT_PROPERTIES:
			var behind: String = "%s.%s" % [node, OBJECT_PROPERTIES[property_name]]
			aliases["%s.%s" % [object_name, property_name]] = behind
			aliases["%s.%s" % [object_name, property_name.to_lower()]] = behind
	for declared_name: String in declared:
		aliases[declared_name] = str(declared[declared_name])
	return aliases


## An expression in the sheet's own words, rewritten as the GDScript the compiler wants.
## Returns {"text": String, "translated": bool} - translated false means a human still has to look.
static func translate_expression(text: String, aliases: Dictionary = {}) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return {"text": "", "translated": true}
	var out: String = _apply_aliases(trimmed, aliases)
	for entry: Array in _expression_patterns():
		out = (entry[0] as RegEx).sub(out, str(entry[1]), true)
	return {"text": out, "translated": not _has_residual(out)}


## Longest name first, so `Player.X` is rewritten before the bare `Player` in it ever could be.
static func _apply_aliases(text: String, aliases: Dictionary) -> String:
	if aliases.is_empty():
		return text
	var names: Array = aliases.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out: String = text
	for name: String in names:
		var pattern: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_.$])%s(?![A-Za-z0-9_])" % name.replace(".", "\\."))
		if pattern == null:
			continue
		# Spliced by hand rather than through RegEx.sub: a replacement here can start with `$`
		# (a node path), and `$` is what a substitution pattern reads as a capture reference.
		var found: Array[RegExMatch] = pattern.search_all(out)
		for index: int in range(found.size() - 1, -1, -1):
			var hit: RegExMatch = found[index]
			out = out.substr(0, hit.get_start()) + str(aliases[name]) + out.substr(hit.get_end())
	return out


## True when a translated value still carries a shape only the other editor understands.
static func _has_residual(text: String) -> bool:
	for pattern: RegEx in _residual_patterns():
		if pattern.search(text) != null:
			return true
	return false


static func _expression_patterns() -> Array:
	if not _compiled_expressions.is_empty():
		return _compiled_expressions
	var compiled: Array = []
	for entry: Array in EXPRESSION_PATTERNS:
		var pattern: RegEx = RegEx.create_from_string(str(entry[0]))
		if pattern != null:
			compiled.append([pattern, str(entry[1])])
	_compiled_expressions = compiled
	return _compiled_expressions


static func _residual_patterns() -> Array:
	if not _compiled_residuals.is_empty():
		return _compiled_residuals
	var compiled: Array = []
	for source: String in RESIDUAL_PATTERNS:
		var pattern: RegEx = RegEx.create_from_string(source)
		if pattern != null:
			compiled.append(pattern)
	_compiled_residuals = compiled
	return _compiled_residuals
