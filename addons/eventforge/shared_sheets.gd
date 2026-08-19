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
		return _include_as_base_class(source, shared_class)
	return _include_as_helper(source, shared_source, shared_class)


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "text": "", "error": error, "wiring": "", "added": PackedStringArray()}


static func _include_as_base_class(source: String, shared_class: String) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		if not lines[index].strip_edges().begins_with("extends "):
			continue
		if lines[index].strip_edges() == "extends %s" % shared_class:
			return _failure("This script already includes %s." % shared_class)
		lines[index] = "extends %s" % shared_class
		return {"ok": true, "text": "\n".join(lines), "error": "", "wiring": WIRING_BASE_CLASS,
			"added": PackedStringArray(["extends %s" % shared_class])}
	return _failure("This script has no `extends` line to include a base class on.")


static func _include_as_helper(source: String, shared_source: String, shared_class: String) -> Dictionary:
	var member: String = member_name_for(shared_class)
	if _declares_member(source, member):
		return _failure("This script already includes %s." % shared_class)
	var written: PackedStringArray = helper_lines(shared_source, shared_class)
	if written.is_empty():
		return _failure("%s has no on_ready / on_tick / on_physics_tick / on_input to forward to." % shared_class)
	var lines: PackedStringArray = source.split("\n")
	var at: int = _insert_point(lines)
	var out: PackedStringArray = PackedStringArray()
	for index: int in lines.size():
		if index == at:
			out.append_array(written)
		out.append(lines[index])
	if at >= lines.size():
		out.append_array(written)
	return {"ok": true, "text": "\n".join(out), "error": "", "wiring": WIRING_HELPER, "added": written}


static func _declares_member(source: String, member: String) -> bool:
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("var %s" % member):
			return true
	return false


## The lines a helper include writes: the one member, and one forwarding function per handler the
## shared sheet declares. Written exactly the way a person would write them by hand, so the file
## reads the same whether the sheet wrote them or the reader did.
static func helper_lines(shared_source: String, shared_class: String) -> PackedStringArray:
	var handlers: PackedStringArray = handlers_of(shared_source)
	if handlers.is_empty():
		return PackedStringArray()
	var member: String = member_name_for(shared_class)
	var out: PackedStringArray = PackedStringArray()
	out.append("var %s := %s.new()" % [member, shared_class])
	for entry: Dictionary in HELPER_HANDLERS:
		var handler: String = str(entry["handler"])
		if not handlers.has(handler):
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
	for index: int in lines.size():
		var text: String = lines[index].strip_edges()
		if text.begins_with("extends ") or text.begins_with("class_name ") or text.begins_with("@icon") \
				or text.begins_with("@tool") or text.begins_with("##") or text.begins_with("#"):
			last_head = index
	if last_head < 0:
		return 0
	var at: int = last_head + 1
	while at < lines.size() and lines[at].strip_edges().is_empty():
		at += 1
	return at


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
