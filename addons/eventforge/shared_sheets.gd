# Godot EventSheets - shared event sheets (write common events once, include them in many scripts).
#
# A shared sheet is an ordinary script whose whole job is to be included by others. There is no new
# file format and no registry: a shared sheet says so in one marker line of its own header, and the
# marker also records the ONE decision that is made per shared sheet rather than per includer -
# HOW it is wired:
#
#   ## @ace_shared_sheet(base_class)   the including script `extends` it, so its events simply are
#                                      the includer's events (the Include bar already reads this)
#   ## @ace_shared_sheet(helper)       the including script keeps one of it, calls it each tick and
#                                      forwards its triggers to it (the sheet writes those rows)
#
# Both are ordinary Godot: one is inheritance, the other is composition. Neither needs the plugin at
# run time, and a project that deletes the addon keeps working, which is the whole parity promise.
#
# WHY THE CHOICE IS MADE ONCE. A shared sheet that is a base class for one script and a helper for
# another would have to be written twice, in two shapes, and a reader opening it could not say which
# one they were reading. Recording it in the shared sheet's own header means every includer wires
# the same way and the "Include sheet…" gesture has nothing left to ask.
#
# The forwarding names are fixed and few on purpose - a helper is called at the four moments a Godot
# script has, and nothing here invents a lifecycle of its own.
@tool
class_name EventSheetSharedSheets
extends RefCounted

## The header marker, and the two wirings it can name. Frozen, like every other `@ace_*` marker.
const MARKER := "## @ace_shared_sheet"
const WIRING_BASE_CLASS := "base_class"
const WIRING_HELPER := "helper"

## The four moments a helper is called at, and the includer function each is forwarded from.
## Ordered as a script runs them, which is the order the written rows appear in.
const HELPER_HANDLERS: Array[Dictionary] = [
	{"handler": "on_ready", "from": "_ready", "signature": "() -> void", "call_args": "self"},
	{"handler": "on_tick", "from": "_process", "signature": "(delta: float) -> void", "call_args": "self, delta"},
	{"handler": "on_physics_tick", "from": "_physics_process", "signature": "(delta: float) -> void", "call_args": "self, delta"},
	{"handler": "on_input", "from": "_input", "signature": "(event: InputEvent) -> void", "call_args": "self, event"},
]

## The sheet trigger that compiles to each of those engine functions - how a finding about a function
## finds the event a reader wrote it with.
const TRIGGER_OF_FUNCTION: Dictionary = {
	"_ready": "OnReady",
	"_process": "OnProcess",
	"_physics_process": "OnPhysicsProcess",
	"_input": "OnInput",
}

## The kind of the one finding this file reports about an includer.
const KIND_BASE_NOT_REACHED := "shared_base_not_reached"


## True when this source is a shared sheet (it carries the marker on a line of its own). Matching
## the marker anywhere in the text would claim this file and its own guide first of all.
static func is_shared_sheet(source: String) -> bool:
	return wiring_of(source) != ""


## Which wiring the shared sheet declares: "base_class", "helper", or "" when it is not one.
## An unknown wiring reads as "not a shared sheet" rather than as a third kind - a file from a newer
## version must degrade to an ordinary script, never to a half-understood one.
static func wiring_of(source: String) -> String:
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.begins_with(MARKER):
			continue
		var inside: String = text.substr(MARKER.length()).strip_edges()
		if not inside.begins_with("(") or not inside.ends_with(")"):
			continue
		var wiring: String = inside.substr(1, inside.length() - 2).strip_edges()
		if wiring == WIRING_BASE_CLASS or wiring == WIRING_HELPER:
			return wiring
	return ""


## How the shared sheet reads in a menu and on the Include bar.
static func wiring_words(wiring: String) -> String:
	return "as a base class" if wiring == WIRING_BASE_CLASS else "as a helper"


## The `class_name` a source declares, or "" - the name an includer has to be able to say.
static func class_name_of(source: String) -> String:
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("class_name "):
			return text.substr("class_name ".length()).strip_edges().split(" ")[0]
	return ""


## The handler names a helper shared sheet actually declares, in HELPER_HANDLERS order. Only these
## are forwarded: writing a forwarding row for a function that is not there would compile to a call
## that fails the moment it runs.
static func handlers_of(shared_source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in HELPER_HANDLERS:
		var handler: String = str(entry["handler"])
		for line: String in shared_source.split("\n"):
			if line.strip_edges().begins_with("func %s(" % handler):
				found.append(handler)
				break
	return found


## A brand-new shared sheet's whole source, ready to save and open. `display_name` is what the
## reader typed ("Pause Handling"); the class name is that name as one word.
static func new_shared_sheet_source(display_name: String, wiring: String) -> String:
	var shared_class: String = class_name_for(display_name)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("## %s - a shared event sheet: its events run in every script that includes it." % display_name)
	lines.append("%s(%s)" % [MARKER, wiring if wiring == WIRING_HELPER else WIRING_BASE_CLASS])
	lines.append("class_name %s" % shared_class)
	if wiring == WIRING_HELPER:
		lines.append("extends RefCounted")
		lines.append("")
		lines.append("")
		lines.append("func on_tick(host: Node, delta: float) -> void:")
		lines.append("\tpass")
	else:
		lines.append("extends Node")
		lines.append("")
		lines.append("")
		lines.append("func _process(delta: float) -> void:")
		lines.append("\tpass")
	lines.append("")
	return "\n".join(lines)


## A display name as a class name: "Pause Handling" reads back as PauseHandling.
static func class_name_for(display_name: String) -> String:
	var out: String = ""
	for word: String in display_name.strip_edges().replace("_", " ").replace("-", " ").split(" ", false):
		out += word.substr(0, 1).to_upper() + word.substr(1)
	return out if not out.is_empty() else "SharedSheet"


## The member name a helper is kept under in the includer: PauseHandling reads back as
## _pause_handling, which is what the forwarding rows address.
static func member_name_for(shared_class: String) -> String:
	return "_" + shared_class.to_snake_case()


## What "Include sheet…" writes into `source`. Returns {ok, text, error, wiring, added}.
## `added` is the lines the sheet wrote, so the confirmation can say them back.
##
## Nothing else in the file is touched: a base-class include rewrites the one `extends` line, and a
## helper include inserts its member and its forwarding functions after the head, leaving every
## existing line where it was.
static func apply_include(source: String, shared_source: String, shared_path: String) -> Dictionary:
	var wiring: String = wiring_of(shared_source)
	if wiring == "":
		return _failure("%s is not a shared sheet - make one with Sheet > New shared sheet…." % shared_path.get_file())
	var shared_class: String = class_name_of(shared_source)
	if shared_class.is_empty():
		return _failure("%s has no class name, so no script can include it." % shared_path.get_file())
	if wiring == WIRING_BASE_CLASS:
		return _include_as_base_class(source, shared_source, shared_class)
	return _include_as_helper(source, shared_source, shared_class)


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "text": "", "error": error, "wiring": "", "added": PackedStringArray()}


## In Godot 4 a script that declares `_process` REPLACES its base's `_process` - the base's runs only
## when the script calls `super(...)`. So pointing `extends` at a shared sheet whose events live in
## `_process` would stop them the moment the includer has a tick of its own. The include therefore
## writes that one `super` call as the first line of every such function the includer already has.
static func _include_as_base_class(source: String, shared_source: String, shared_class: String) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		if not lines[index].strip_edges().begins_with("extends "):
			continue
		if lines[index].strip_edges() == "extends %s" % shared_class:
			return _failure("This script already includes %s." % shared_class)
		lines[index] = "extends %s" % shared_class
		var added: PackedStringArray = PackedStringArray(["extends %s" % shared_class])
		for entry: Dictionary in HELPER_HANDLERS:
			var function_name: String = str(entry["from"])
			if _function_at(shared_source.split("\n"), function_name) < 0:
				continue
			var at: int = _function_at(lines, function_name)
			if at < 0 or _body_calls_super(lines, at):
				continue
			var header: Dictionary = _header_arguments(lines[at], _arity_of(entry))
			var call: String = "super(%s)" % ", ".join(header.get("names", PackedStringArray()))
			if not bool(header["ok"]):
				return _failure(_cannot_add_to(function_name, str(header["why"]), call))
			lines.insert(at + 1, _body_indent(lines, at) + call)
			added.append(call)
		return {"ok": true, "text": "\n".join(lines), "error": "", "wiring": WIRING_BASE_CLASS,
			"added": added}
	return _failure("This script has no `extends` line to include a base class on.")


static func _include_as_helper(source: String, shared_source: String, shared_class: String) -> Dictionary:
	var member: String = member_name_for(shared_class)
	if _declares_member(source, member):
		return _failure("This script already includes %s." % shared_class)
	var handlers: PackedStringArray = handlers_of(shared_source)
	if handlers.is_empty():
		return _failure("%s has no on_ready / on_tick / on_physics_tick / on_input to forward to." % shared_class)
	var lines: PackedStringArray = source.split("\n")
	# A function the includer ALREADY declares gets the one forwarding call as its first statement:
	# writing a second `func _process` beside the first is a script Godot refuses to parse.
	var merged: PackedStringArray = PackedStringArray()
	for entry: Dictionary in HELPER_HANDLERS:
		var handler: String = str(entry["handler"])
		var function_name: String = str(entry["from"])
		if not handlers.has(handler):
			continue
		var existing: int = _function_at(lines, function_name)
		if existing < 0:
			continue
		var header: Dictionary = _header_arguments(lines[existing], _arity_of(entry))
		var args: PackedStringArray = PackedStringArray(["self"])
		args.append_array(header.get("names", PackedStringArray()))
		var call: String = "%s.%s(%s)" % [member, handler, ", ".join(args)]
		if not bool(header["ok"]):
			return _failure(_cannot_add_to(function_name, str(header["why"]),
				"%s.%s(%s)" % [member, handler, str(entry["call_args"])]))
		lines.insert(existing + 1, _body_indent(lines, existing) + call)
		merged.append(function_name)
	var written: PackedStringArray = helper_lines(shared_source, shared_class, merged)
	var at: int = _insert_point(lines)
	var out: PackedStringArray = PackedStringArray()
	for index: int in lines.size():
		if index == at:
			out.append_array(written)
		out.append(lines[index])
	if at >= lines.size():
		out.append_array(written)
	var added: PackedStringArray = written.duplicate()
	for function_name: String in merged:
		for entry: Dictionary in HELPER_HANDLERS:
			if str(entry["from"]) == function_name:
				added.append("%s.%s(...)" % [member, str(entry["handler"])])
	return {"ok": true, "text": "\n".join(out), "error": "", "wiring": WIRING_HELPER, "added": added}


static func _declares_member(source: String, member: String) -> bool:
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("var %s" % member):
			return true
	return false


## The lines a helper include writes: the one member, and one forwarding function per handler the
## shared sheet declares. Written exactly the way a person would write them by hand, so the file
## reads the same whether the sheet wrote them or the reader did.
##
## `skip` names the engine functions the includer already declares; those get their call merged into
## the existing body instead, so no function is written twice.
static func helper_lines(shared_source: String, shared_class: String,
		skip: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var handlers: PackedStringArray = handlers_of(shared_source)
	if handlers.is_empty():
		return PackedStringArray()
	var member: String = member_name_for(shared_class)
	var out: PackedStringArray = PackedStringArray()
	out.append("var %s := %s.new()" % [member, shared_class])
	for entry: Dictionary in HELPER_HANDLERS:
		var handler: String = str(entry["handler"])
		if not handlers.has(handler) or skip.has(str(entry["from"])):
			continue
		out.append("")
		out.append("")
		out.append("func %s%s:" % [str(entry["from"]), str(entry["signature"])])
		out.append("\t%s.%s(%s)" % [member, handler, str(entry["call_args"])])
	out.append("")
	out.append("")
	return out


## Where the written lines go: after the head (the class doc, the markers, class_name, extends and
## any @icon), before the first member or function. A file whose head is its whole content gets them
## at the end.
static func _insert_point(lines: PackedStringArray) -> int:
	var last_head: int = -1
	# Only the LEADING run counts: a comment inside a function body further down is not the head,
	# and treating it as one put the written member inside that function.
	for index: int in lines.size():
		var text: String = lines[index].strip_edges()
		if text.is_empty():
			continue
		if text.begins_with("extends ") or text.begins_with("class_name ") or text.begins_with("@icon") \
				or text.begins_with("@tool") or text.begins_with("##") or text.begins_with("#"):
			last_head = index
			continue
		break
	if last_head < 0:
		return 0
	var at: int = last_head + 1
	while at < lines.size() and lines[at].strip_edges().is_empty():
		at += 1
	return at


## The line index of a top-level `func <name>(`, or -1. Top-level means unindented: a nested class's
## function of the same name is not the one Godot calls on this node.
static func _function_at(lines: PackedStringArray, function_name: String) -> int:
	for index: int in lines.size():
		if lines[index].begins_with("func %s(" % function_name):
			return index
	return -1


## How many arguments Godot passes to the engine function an entry forwards from.
static func _arity_of(entry: Dictionary) -> int:
	var inside: String = str(entry["signature"]).get_slice("(", 1).get_slice(")", 0).strip_edges()
	return 0 if inside.is_empty() else inside.split(",").size()


## The argument names a function header declares, as {ok, names, why}. Only a header that fits on
## its own line and ends in `:` can be added to - a one-line body or a header broken over lines is
## refused with the reason rather than edited into something that does not parse.
static func _header_arguments(header: String, arity: int) -> Dictionary:
	var open: int = header.find("(")
	var close: int = header.find(")", open)
	if open < 0 or close < 0 or not header.strip_edges().ends_with(":"):
		return {"ok": false, "names": PackedStringArray(), "why": "its first line is not a whole header ending in a colon"}
	var names: PackedStringArray = PackedStringArray()
	for part: String in header.substr(open + 1, close - open - 1).split(",", false):
		var argument: String = part.get_slice(":", 0).get_slice("=", 0).strip_edges()
		if not argument.is_empty():
			names.append(argument)
	if names.size() != arity:
		return {"ok": false, "names": names,
			"why": "it takes %d argument(s) where Godot passes %d" % [names.size(), arity]}
	return {"ok": true, "names": names, "why": ""}


## The indentation of a function's first statement, so a line put above it lines up with it.
static func _body_indent(lines: PackedStringArray, header_index: int) -> String:
	for index: int in range(header_index + 1, lines.size()):
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			continue
		var indent: String = line.substr(0, line.length() - line.strip_edges(true, false).length())
		return indent if not indent.is_empty() else "\t"
	return "\t"


## True when a function's body already calls its base - an include run twice, or a reader who wrote
## it by hand, must not get a second one.
static func _body_calls_super(lines: PackedStringArray, header_index: int) -> bool:
	for index: int in range(header_index + 1, lines.size()):
		var line: String = lines[index]
		if not line.strip_edges().is_empty() and not line.begins_with("\t") and not line.begins_with(" "):
			return false
		if line.strip_edges().begins_with("super"):
			return true
	return false


static func _cannot_add_to(function_name: String, why: String, call: String) -> String:
	return "This script's %s cannot be added to automatically - %s. Put %s at the top of it by hand." % [
		function_name, why, call]


## The base-class include's one silent failure, asked of an includer and the shared sheet it extends:
## every engine function both declare where the includer's never calls `super` - Godot 4 runs only
## the includer's, so the shared sheet's events on that trigger stop without a word. Returns
## {kind, subject, message} per function; `subject` is the function, which is how the canvas finds
## the event that wrote it.
static func base_not_reached(source: String, shared_class: String, shared_source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if wiring_of(shared_source) != WIRING_BASE_CLASS:
		return found
	var lines: PackedStringArray = source.split("\n")
	var shared_lines: PackedStringArray = shared_source.split("\n")
	for entry: Dictionary in HELPER_HANDLERS:
		var function_name: String = str(entry["from"])
		var at: int = _function_at(lines, function_name)
		if at < 0 or _function_at(shared_lines, function_name) < 0 or _body_calls_super(lines, at):
			continue
		var names: PackedStringArray = _header_arguments(lines[at], _arity_of(entry)).get("names", PackedStringArray())
		found.append({
			"kind": KIND_BASE_NOT_REACHED,
			"subject": function_name,
			"message": "%s's %s events no longer run - this script's own %s replaces them. Call super(%s) first in it." % [
				shared_class, _handler_words(str(entry["handler"])), function_name, ", ".join(names)],
		})
	return found


## The same question asked of a script on disk: which shared sheet it extends, read off its own
## `extends` line and the project's class list. Empty for a script that extends no shared sheet.
static func base_not_reached_in_file(script_path: String) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return none
	var source: String = FileAccess.get_file_as_string(script_path)
	var base: String = ""
	for line: String in source.split("\n"):
		if line.begins_with("extends "):
			base = line.substr("extends ".length()).strip_edges()
			break
	if base.is_empty() or base.begins_with("\""):
		return none
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == base:
			var base_path: String = str(entry.get("path", ""))
			if FileAccess.file_exists(base_path):
				return base_not_reached(source, base, FileAccess.get_file_as_string(base_path))
	return none


## Every shared sheet an includer's source pulls in: an Array of {wiring, class, member}. Read off
## the includer alone, so the Include bar can name them without loading anything.
static func includes_in(source: String, known: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("extends "):
			var base: String = text.substr("extends ".length()).strip_edges()
			if known.has(base):
				out.append({"wiring": WIRING_BASE_CLASS, "class": base, "member": ""})
			continue
		if not text.begins_with("var "):
			continue
		for shared_class: Variant in known:
			if text.contains("%s.new()" % str(shared_class)):
				out.append({"wiring": WIRING_HELPER, "class": str(shared_class),
					"member": text.substr("var ".length()).split(" ")[0].split(":")[0]})
				break
	return out


## The Doctor's question about includes: does more than one of them handle the SAME trigger? Two
## shared sheets that both answer "on input" both run, in include order, and the second one's answer
## is the one that lasts - the single confusion a reader of the includer cannot see, because neither
## handler is written there.
##
## `sources_by_class` is {class name: that shared sheet's source}. Returns one message per clash.
static func duplicate_trigger_messages(source: String, sources_by_class: Dictionary) -> PackedStringArray:
	var handled: Dictionary = {}
	for include: Dictionary in includes_in(source, sources_by_class):
		var shared_class: String = str(include["class"])
		var shared_source: String = str(sources_by_class.get(shared_class, ""))
		for handler: String in handlers_of(shared_source):
			var owners: Array = handled.get(handler, []) as Array
			owners.append(shared_class)
			handled[handler] = owners
	var out: PackedStringArray = PackedStringArray()
	for handler: Variant in handled:
		var owners: Array = handled[str(handler)] as Array
		if owners.size() < 2:
			continue
		out.append("Two included sheets handle %s - %s. Both run, in include order, and the last one wins." % [
			_handler_words(str(handler)), " and ".join(PackedStringArray(owners))])
	out.sort()
	return out


static func _handler_words(handler: String) -> String:
	match handler:
		"on_ready":
			return "On created"
		"on_tick":
			return "Every tick"
		"on_physics_tick":
			return "Every tick (physics)"
		"on_input":
			return "On input"
	return handler
