@tool
class_name EventSheetMemberCatalog
extends RefCounted

# What can follow a dot: the members of one TYPE, read from the engine and never typed out by hand.
#
# Three kinds of type answer here, and all three through reflection:
# - an engine CLASS (Node2D, AnimatedSprite2D, Input): ClassDB, live, so a project's own extensions
#   are in it and a new engine version needs no change here;
# - a built-in VALUE type (Vector2, Color, String, Array...): the reduced class reference, which the
#   engine publishes about itself (see EventSheetClassReference) - ClassDB does not know these;
# - a SCRIPT type ("script:res://enemy.gd"): what the file declares, with its `##` comments, over its
#   base class.
#
# An entry is {"text": what typing it inserts, "label": the name with its arguments, "kind": one of
# the KIND words below, "type": the type in Godot's spelling (a method's is what it returns),
# "detail": the class that declares it, "lower": the bare name lowered for ranking, "owner", "member"
# and "member_kind" ("p" property, "m" method, "s" signal, "c" constant) to find its description
# later}. The description is NOT read here: it is asked for when an entry is highlighted, so
# building a type's list never opens the class reference.
#
# Built once per type and held. A list is read-only for everyone who gets it.

const ClassReference := preload("res://addons/eventsheet/ace/class_reference.gd")
## Read by path when a script type is listed: naming it here would compile it into every first open.
const SCRIPT_MEMBERS_PATH := "res://addons/eventsheet/ace/script_members.gd"

const KIND_PROPERTY := "property"
const KIND_METHOD := "method"
const KIND_SIGNAL := "signal"
const KIND_CONSTANT := "constant"

## Prefix of a type descriptor naming a script rather than a class.
const SCRIPT_PREFIX := "script:"
## Prefix of a type descriptor naming one of the sheet's own enums.
const ENUM_PREFIX := "enum:"

const _NIL_IS_VARIANT := 131072

static var _members: Dictionary = {}
static var _statics: Dictionary = {}


## Drops what was built. The filesystem ping calls it (a script edited changes its members).
static func clear_cache() -> void:
	_members.clear()
	_statics.clear()


## True when this catalog can list members of `type_name`.
static func knows(type_name: String) -> bool:
	if type_name.begins_with(SCRIPT_PREFIX):
		return true
	return ClassDB.class_exists(type_name) or ClassReference.has_builtin(type_name)


## The base of a type spelled with a generic suffix: "Array[int]" is an Array.
static func base_of(type_name: String) -> String:
	var bracket: int = type_name.find("[")
	return type_name.substr(0, bracket).strip_edges() if bracket >= 0 else type_name.strip_edges()


## The type an element of a typed collection has ("Array[int]" gives "int"), "" when it is untyped.
static func element_of(type_name: String) -> String:
	var open: int = type_name.find("[")
	if open < 0 or not type_name.ends_with("]"):
		return ""
	var inside: String = type_name.substr(open + 1, type_name.length() - open - 2)
	if base_of(type_name) == "Dictionary":
		return inside.get_slice(",", 1).strip_edges()
	return inside.strip_edges()


## Everything an INSTANCE of `type_name` offers after a dot: properties, methods, signals.
static func members(type_name: String) -> Array[Dictionary]:
	var key: String = base_of(type_name)
	if _members.has(key):
		return _members[key]
	var built: Array[Dictionary] = []
	if key.begins_with(SCRIPT_PREFIX):
		built = _script_members(key.trim_prefix(SCRIPT_PREFIX))
	elif ClassDB.class_exists(key):
		built = _class_members(key)
	elif ClassReference.has_builtin(key):
		built = _builtin_members(key)
	# An empty answer is not held: the class reference may simply not be built yet.
	if not built.is_empty():
		_members[key] = built
	return built


## What the TYPE ITSELF offers after a dot - `Vector2.ZERO`, `Color.RED`, `Node.PROCESS_MODE_ALWAYS`,
## `Time.get_ticks_msec()`: its constants, enum values and static functions.
static func statics(type_name: String) -> Array[Dictionary]:
	var key: String = base_of(type_name)
	if _statics.has(key):
		return _statics[key]
	var built: Array[Dictionary] = []
	if ClassDB.class_exists(key):
		built = _class_statics(key)
	elif ClassReference.has_builtin(key):
		built = _builtin_statics(key)
	if not built.is_empty():
		_statics[key] = built
	return built


## The type a member of `type_name` has (what a method returns), "" when it is not known or too
## general to walk on (void, Variant). `through_statics` reads the type-level list instead.
static func member_type(type_name: String, member_name: String, through_statics: bool = false) -> String:
	var list: Array[Dictionary] = statics(type_name) if through_statics else members(type_name)
	for entry: Dictionary in list:
		if str(entry.get("member", "")) == member_name:
			var walked: String = str(entry.get("walk", entry.get("type", "")))
			return "" if walked in ["void", "Variant", ""] else walked
	return ""


## One method of `type_name`, found through the inheritance chain: {"args": [{"n", "t", "v"}],
## "ret": String, "va": bool, "owner": String}. {} when the type has no such method.
static func method_info(type_name: String, method_name: String, through_statics: bool = false) -> Dictionary:
	var list: Array[Dictionary] = statics(type_name) if through_statics else members(type_name)
	for entry: Dictionary in list:
		if str(entry.get("member", "")) == method_name and str(entry.get("member_kind", "")) == "m":
			return entry.get("signature", {})
	# A static function is callable from an instance, and a constructor-free type may list it there.
	if not through_statics:
		for entry: Dictionary in statics(type_name):
			if str(entry.get("member", "")) == method_name and str(entry.get("member_kind", "")) == "m":
				return entry.get("signature", {})
	return {}


## The one line that says what an entry is, asked for when it is highlighted: the type or class that
## declares it, then the first sentence of the class reference. "" when there is nothing to say.
static func describe(entry: Dictionary) -> String:
	var owner: String = str(entry.get("owner", ""))
	var said: String = str(entry.get("doc", ""))
	if said.is_empty() and bool(entry.get("engine", false)):
		said = ClassReference.describe(owner, str(entry.get("member_kind", "")), str(entry.get("member", "")))
		if said.is_empty() and str(entry.get("member_kind", "")) == "c" and not ClassReference.enum_of(str(entry.get("member", ""))).is_empty():
			said = ClassReference.describe_enum_value(str(entry.get("member", "")))
	if owner.is_empty():
		return said
	return owner if said.is_empty() else "%s %s %s" % [owner, "·", said]


## True when the line `describe` gave for this entry is the engine's own prose (which carries its
## credit with it).
static func is_engine_prose(entry: Dictionary) -> bool:
	return bool(entry.get("engine", false)) and str(entry.get("doc", "")).is_empty()


## The type a ClassDB property / argument / return info dictionary names, in Godot's spelling.
static func spelling(info: Dictionary, is_return: bool = false) -> String:
	var named: String = str(info.get("class_name", ""))
	var value_type: int = int(info.get("type", TYPE_NIL))
	if value_type == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE and not str(info.get("hint_string", "")).is_empty():
		return "Array[%s]" % str(info.get("hint_string", ""))
	if not named.is_empty():
		return named
	if value_type == TYPE_NIL:
		if int(info.get("usage", 0)) & _NIL_IS_VARIANT or not is_return:
			return "Variant"
		return "void"
	if value_type == TYPE_OBJECT:
		return "Object"
	return type_string(value_type)


## A default value the way Godot spells it in a hint: &"" for a StringName, 1.0 for a float.
static func default_literal(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_STRING_NAME:
			return "&\"%s\"" % str(value)
		TYPE_STRING:
			return "\"%s\"" % str(value)
		TYPE_FLOAT:
			var text: String = str(value)
			return text if text.contains(".") or text.contains("e") or text.contains("inf") or text.contains("nan") else text + ".0"
		TYPE_OBJECT:
			return "null"
	return var_to_str(value)


# ── Engine classes ────────────────────────────────────────────────────────────────────────


static func _class_members(class_text: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var seen: Dictionary = {}
	var chain: PackedStringArray = _chain(class_text)
	# Properties first (what a reader reaches for), then methods, then signals - each from the most
	# specific class up, so a class's own members lead the ones it inherits.
	for owner: String in chain:
		for info: Dictionary in ClassDB.class_get_property_list(owner, true):
			var name_text: String = str(info.get("name", ""))
			if name_text.is_empty() or name_text.begins_with("_") or name_text.contains("/") or seen.has(name_text):
				continue
			if int(info.get("usage", 0)) & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
				continue
			seen[name_text] = true
			list.append(_entry(KIND_PROPERTY, name_text, name_text, name_text, spelling(info), owner, "p"))
	for owner: String in chain:
		for info: Dictionary in ClassDB.class_get_method_list(owner, true):
			var method_name: String = str(info.get("name", ""))
			if method_name.is_empty() or method_name.begins_with("_") or seen.has(method_name) or int(info.get("flags", 0)) & METHOD_FLAG_VIRTUAL:
				continue
			seen[method_name] = true
			list.append(_method_entry(method_name, owner, _class_signature(info)))
	for owner: String in chain:
		for info: Dictionary in ClassDB.class_get_signal_list(owner, true):
			var signal_name: String = str(info.get("name", ""))
			if signal_name.is_empty() or seen.has(signal_name):
				continue
			seen[signal_name] = true
			var names: PackedStringArray = PackedStringArray()
			for argument: Dictionary in info.get("args", []):
				names.append(str(argument.get("name", "")))
			var label: String = "%s(%s)" % [signal_name, ", ".join(names)] if not names.is_empty() else signal_name
			list.append(_entry(KIND_SIGNAL, signal_name, signal_name, label, "Signal", owner, "s"))
	return list


static func _class_statics(class_text: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var seen: Dictionary = {}
	for owner: String in _chain(class_text):
		for constant: String in ClassDB.class_get_integer_constant_list(owner, true):
			if seen.has(constant):
				continue
			seen[constant] = true
			var enum_name: String = str(ClassDB.class_get_integer_constant_enum(owner, constant, true))
			var value: int = ClassDB.class_get_integer_constant(owner, constant)
			var shown: String = "%s = %d" % ["%s.%s" % [owner, enum_name] if not enum_name.is_empty() else "int", value]
			var entry: Dictionary = _entry(KIND_CONSTANT, constant, constant, constant, shown, owner, "c")
			entry["walk"] = "int"
			list.append(entry)
		for info: Dictionary in ClassDB.class_get_method_list(owner, true):
			var method_name: String = str(info.get("name", ""))
			if method_name.is_empty() or method_name.begins_with("_") or seen.has(method_name) or not (int(info.get("flags", 0)) & METHOD_FLAG_STATIC):
				continue
			seen[method_name] = true
			list.append(_method_entry(method_name, owner, _class_signature(info)))
	return list


## The ancestors of a class, itself first, ending at Object.
static func _chain(class_text: String) -> PackedStringArray:
	var chain: PackedStringArray = PackedStringArray()
	var current: String = class_text
	while not current.is_empty():
		chain.append(current)
		current = str(ClassDB.get_parent_class(current))
	return chain


static func _class_signature(info: Dictionary) -> Dictionary:
	var arguments: Array = info.get("args", [])
	var defaults: Array = info.get("default_args", [])
	var first_default: int = arguments.size() - defaults.size()
	var args: Array = []
	for index: int in range(arguments.size()):
		var argument: Dictionary = arguments[index]
		args.append({"n": str(argument.get("name", "")), "t": spelling(argument),
			"v": default_literal(defaults[index - first_default]) if index >= first_default else ""})
	return {"args": args, "ret": spelling(info.get("return", {}), true),
		"va": bool(int(info.get("flags", 0)) & METHOD_FLAG_VARARG)}


# ── Built-in value types ──────────────────────────────────────────────────────────────────


static func _builtin_members(type_text: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var data: Dictionary = ClassReference.builtin(type_text)
	for member: Dictionary in data.get("members", []):
		var name_text: String = str(member.get("n", ""))
		list.append(_entry(KIND_PROPERTY, name_text, name_text, name_text, str(member.get("t", "")), type_text, "p", true))
	for method: Dictionary in data.get("methods", []):
		list.append(_method_entry(str(method.get("n", "")), type_text, _builtin_signature(method), true))
	return list


static func _builtin_statics(type_text: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var data: Dictionary = ClassReference.builtin(type_text)
	for constant: Dictionary in data.get("constants", []):
		var name_text: String = str(constant.get("n", ""))
		list.append(_entry(KIND_CONSTANT, name_text, name_text, name_text, str(constant.get("t", "")), type_text, "c", true))
	for method: Dictionary in data.get("methods", []):
		if bool(method.get("s", false)):
			list.append(_method_entry(str(method.get("n", "")), type_text, _builtin_signature(method), true))
	return list


static func _builtin_signature(method: Dictionary) -> Dictionary:
	var args: Array = []
	for argument: Dictionary in method.get("a", []):
		args.append({"n": str(argument.get("n", "")), "t": str(argument.get("t", "")), "v": str(argument.get("v", ""))})
	var returned: String = str(method.get("r", ""))
	return {"args": args, "ret": returned if not returned.is_empty() else "void", "va": bool(method.get("va", false))}


# ── Scripts ───────────────────────────────────────────────────────────────────────────────


static func _script_members(script_path: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var declared: Dictionary = load(SCRIPT_MEMBERS_PATH).of_script(script_path)
	var seen: Dictionary = {}
	var owner: String = script_path.get_file()
	for property: Dictionary in declared.get("properties", []):
		var name_text: String = str(property.get("name", ""))
		if name_text.is_empty() or seen.has(name_text):
			continue
		seen[name_text] = true
		var entry: Dictionary = _entry(KIND_PROPERTY, name_text, name_text, name_text, str(property.get("args", "")), owner, "p")
		entry["engine"] = false
		entry["doc"] = str(property.get("doc", ""))
		list.append(entry)
	for method: Dictionary in declared.get("methods", []):
		var method_name: String = str(method.get("name", ""))
		if method_name.is_empty() or seen.has(method_name):
			continue
		seen[method_name] = true
		var arguments: String = str(method.get("args", "")).strip_edges()
		var returned: String = str(method.get("ret", ""))
		var entry: Dictionary = _entry(KIND_METHOD, method_name, method_name + "()",
			"%s(%s)" % [method_name, arguments], returned if not returned.is_empty() else "void", owner, "m")
		entry["engine"] = false
		entry["doc"] = str(method.get("doc", ""))
		entry["signature"] = {"args": _declared_arguments(arguments), "ret": returned if not returned.is_empty() else "void", "va": false}
		entry["caret_back"] = 1 if not arguments.is_empty() else 0
		list.append(entry)
	for declared_signal: Dictionary in declared.get("signals", []):
		var signal_name: String = str(declared_signal.get("name", ""))
		if signal_name.is_empty() or seen.has(signal_name):
			continue
		seen[signal_name] = true
		var entry: Dictionary = _entry(KIND_SIGNAL, signal_name, signal_name, signal_name, "Signal", owner, "s")
		entry["engine"] = false
		entry["doc"] = str(declared_signal.get("doc", ""))
		list.append(entry)
	var base: String = str(declared.get("base", ""))
	if not base.is_empty() and ClassDB.class_exists(base):
		for inherited: Dictionary in members(base):
			if not seen.has(str(inherited.get("member", ""))):
				list.append(inherited)
	return list


## A script's arguments as the file writes them (`amount: int = 1, who`) as signature arguments.
static func _declared_arguments(text: String) -> Array:
	var args: Array = []
	if text.strip_edges().is_empty():
		return args
	for part: String in text.split(","):
		var piece: String = part.strip_edges()
		var default_text: String = ""
		if piece.contains("="):
			default_text = piece.get_slice("=", 1).strip_edges()
			piece = piece.get_slice("=", 0).strip_edges()
		args.append({"n": piece.get_slice(":", 0).strip_edges(), "t": piece.get_slice(":", 1).strip_edges() if piece.contains(":") else "", "v": default_text})
	return args


# ── Entries ───────────────────────────────────────────────────────────────────────────────


static func _entry(kind: String, name_text: String, text: String, label: String, type_text: String, owner: String, member_kind: String, is_builtin: bool = false) -> Dictionary:
	return {"text": text, "label": label, "kind": kind, "type": type_text, "detail": owner,
		"lower": name_text.to_lower(), "owner": owner, "member": name_text, "member_kind": member_kind,
		"engine": true, "builtin": is_builtin}


static func _method_entry(method_name: String, owner: String, signature: Dictionary, is_builtin: bool = false) -> Dictionary:
	var names: PackedStringArray = PackedStringArray()
	for argument: Dictionary in signature.get("args", []):
		names.append(str(argument.get("n", "")))
	var has_args: bool = not names.is_empty() or bool(signature.get("va", false))
	var entry: Dictionary = _entry(KIND_METHOD, method_name, method_name + "()",
		"%s(%s)" % [method_name, ", ".join(names)], str(signature.get("ret", "")), owner, "m", is_builtin)
	entry["signature"] = signature
	entry["caret_back"] = 1 if has_args else 0
	return entry
