# Godot EventSheets - writes `## @ace_*` annotations into a user's own script.
#
# This is the half of the ACE wizard that touches the user's file, so it is deliberately the
# smallest, dumbest thing that can work: pure text in, pure text out, no file IO, no Script
# loading, no reflection. The dialog does the deciding; this does the editing.
#
# WHY ANNOTATIONS AND NOT A SIDE STORE. They are the format the analyzer already reads, so
# "curate it now, reopen and adjust later" is round-trip by construction. They document the script
# for the user's teammates. And they survive without the plugin - deleting EventSheets leaves a
# file full of harmless comments rather than a broken one. A parallel metadata store would be a
# second source of truth that can silently desync from the code it describes.
#
# THE THREE GUARANTEES
#
# 1. IDEMPOTENT. Applying the same edits twice produces identical text. Achieved by rewriting
#    rather than appending: every managed annotation in the block is removed first, then the whole
#    set is re-emitted in a canonical order. A second pass removes exactly what the first wrote.
# 2. NOTHING BUT COMMENTS MOVES. Only `##` lines above a declaration are added or removed. No
#    signature, no body, no decorator, no blank line between members is ever touched. That is why
#    an untyped method's KIND is fixed by writing `@ace_condition` rather than by adding `-> bool`:
#    editing someone's signature to change how a picker groups it is not a trade worth offering.
# 3. UNRECOGNISED MEMBERS FAIL LOUDLY. An edit whose declaration cannot be found is reported in
#    `skipped`, never silently dropped - a rename between scan and apply must not look like success.
#
# Non-managed `##` lines (the human's own doc comment) are preserved verbatim, and stay above the
# annotations - which is also the order the compiler emits, so a curated file reads like a pack.
@tool
class_name EventSheetACEAnnotationWriter
extends RefCounted

## Annotations this writer owns. Anything else in the block belongs to the user and is left alone -
## including `@ace_icon`, `@ace_deprecated` and the rest, which the wizard does not offer to edit
## and therefore must not clear.
const MANAGED_ANNOTATIONS: PackedStringArray = [
	"@ace_hidden", "@ace_action", "@ace_condition", "@ace_expression", "@ace_trigger",
	"@ace_name", "@ace_category", "@ace_description", "@ace_param"
]

## The kind annotations, keyed by the `kind` an edit may ask for.
const KIND_ANNOTATIONS: Dictionary = {
	"action": "@ace_action",
	"condition": "@ace_condition",
	"expression": "@ace_expression",
	"trigger": "@ace_trigger"
}


## Applies curation edits to provider source text.
##
## Each edit is a Dictionary describing ONE member:
##   {"source_kind": "method"|"signal"|"property", "member": "start_wave",
##    "hidden": bool, "kind": "condition", "name": "Wave Active", "category": "Waves",
##    "description": "True while a wave is running.",
##    "params": {"count": {"default": "3", "options": "a=A|b=B", "hint": "comparison"}}}
##
## Only the keys present are written, so curating just the label leaves everything else as it was.
## `hidden` wins outright - a member the author opted out of needs no label or category.
##
## Returns {"ok", "source", "changed", "skipped", "reason"}. `source` is unchanged when ok is false.
static func apply(source: String, edits: Array) -> Dictionary:
	var result: Dictionary = {"ok": false, "source": source, "changed": 0, "skipped": [], "reason": ""}
	if edits.is_empty():
		result["ok"] = true
		return result
	# Windows files round-trip: split on \n, restore the carriage returns at the end rather than
	# leaving a stray \r welded to the end of every line.
	var crlf: bool = source.contains("\r\n")
	var lines: PackedStringArray = source.replace("\r\n", "\n").split("\n")

	# Anchor every edit FIRST, against the untouched text, then apply bottom-up. Re-scanning after
	# each edit would work too, but anchoring once means a member named in two edits cannot have the
	# second one land against text the first already moved.
	var anchored: Array = []
	for edit: Variant in edits:
		if not (edit is Dictionary):
			continue
		var entry: Dictionary = edit as Dictionary
		var anchor: int = find_declaration(lines, str(entry.get("source_kind", "method")), str(entry.get("member", "")))
		if anchor < 0:
			(result["skipped"] as Array).append(str(entry.get("member", "")))
			continue
		anchored.append({"anchor": anchor, "edit": entry})
	# Several edits can land on ONE declaration: an exported property publishes both a reader and a
	# writer, and the curation table shows them as two rows. They share a `var`, so they share an
	# annotation block - rewriting it twice would leave only the second edit's annotations.
	var merged: Dictionary = {}
	for item: Dictionary in anchored:
		var anchor: int = int(item["anchor"])
		var edit: Dictionary = item["edit"] as Dictionary
		if not merged.has(anchor):
			merged[anchor] = edit.duplicate(true)
			continue
		var combined: Dictionary = merged[anchor] as Dictionary
		var was_hidden: bool = bool(combined.get("hidden", false))
		combined.merge(edit, true)
		# Opting out is sticky: hiding a property from one of its two rows must not be undone by
		# the other row, which the user never touched.
		if was_hidden or bool(edit.get("hidden", false)):
			combined["hidden"] = true
		merged[anchor] = combined

	var anchors: Array = merged.keys()
	anchors.sort()
	anchors.reverse()
	for anchor: int in anchors:
		lines = _rewrite_block(lines, anchor, merged[anchor] as Dictionary)
		result["changed"] = int(result["changed"]) + 1

	var rebuilt: String = "\n".join(lines)
	result["source"] = rebuilt.replace("\n", "\r\n") if crlf else rebuilt
	result["ok"] = true
	return result


## The line index of a member's declaration, or -1.
##
## Only column-zero declarations count: a `func` indented inside an inner class is not a member of
## the provider, and annotating it would put the comment somewhere it means nothing.
static func find_declaration(lines: PackedStringArray, source_kind: String, member: String) -> int:
	if member.strip_edges().is_empty():
		return -1
	var pattern: RegEx = RegEx.new()
	match source_kind:
		"signal":
			pattern.compile("^signal\\s+%s\\s*[(:]?" % _escaped(member))
		"property", "set", "add", "subtract":
			# `var speed`, `@export var speed`, `@export_range(0, 9) var speed` - the annotation may
			# sit on the same line as the declaration or on its own line above it.
			#
			# All four kinds anchor here on purpose: ONE numeric `@export` publishes a reader, a
			# setter, an add and a subtract, and every one of them is a view of the same `var`.
			# Matching only "property" and "set" sent the other two hunting for a `func` of that
			# name, so unchecking the Add row reported the member as missing.
			pattern.compile("^(@\\w+(\\(.*\\))?\\s+)*(static\\s+)?var\\s+%s\\s*[:=]" % _escaped(member))
		_:
			pattern.compile("^(static\\s+)?func\\s+%s\\s*\\(" % _escaped(member))
	for index: int in range(lines.size()):
		if pattern.search(lines[index]) != null:
			return index
	return -1


## The first line of the comment block that belongs to the declaration at `anchor`: walks up over
## the declaration's own decorator lines (`@export`, `@rpc`, …) and then over its `##` doc lines.
static func block_start(lines: PackedStringArray, anchor: int) -> int:
	var start: int = anchor
	while start > 0:
		var previous: String = lines[start - 1].strip_edges()
		if previous.begins_with("##") or (previous.begins_with("@") and not previous.begins_with("@ace")):
			start -= 1
			continue
		break
	return start


static func _rewrite_block(lines: PackedStringArray, anchor: int, edit: Dictionary) -> PackedStringArray:
	var start: int = block_start(lines, anchor)
	# The block splits into three: the user's own `##` prose, their decorators, and our annotations.
	# Prose stays on top, decorators must stay welded to the declaration, and ours goes between.
	var prose: PackedStringArray = PackedStringArray()
	var decorators: PackedStringArray = PackedStringArray()
	var indent: String = _leading_whitespace(lines[anchor])
	for index: int in range(start, anchor):
		var line: String = lines[index]
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("@") and not trimmed.begins_with("@ace"):
			decorators.append(line)
		elif trimmed.begins_with("##") and not _is_managed(trimmed):
			prose.append(line)
		elif not trimmed.begins_with("##"):
			decorators.append(line)

	var rebuilt: PackedStringArray = PackedStringArray()
	for index: int in range(0, start):
		rebuilt.append(lines[index])
	rebuilt.append_array(prose)
	for annotation: String in annotation_lines(edit):
		rebuilt.append("%s%s" % [indent, annotation])
	rebuilt.append_array(decorators)
	for index: int in range(anchor, lines.size()):
		rebuilt.append(lines[index])
	return rebuilt


## The managed annotation lines an edit produces, in canonical order. Exposed on its own so a diff
## preview can show exactly what will be written without applying anything.
static func annotation_lines(edit: Dictionary) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	# Opting a member out is the whole statement - a hidden verb has no label to argue about.
	if bool(edit.get("hidden", false)):
		output.append("## @ace_hidden")
		return output
	var kind: String = str(edit.get("kind", "")).strip_edges().to_lower()
	if KIND_ANNOTATIONS.has(kind):
		output.append("## %s" % KIND_ANNOTATIONS[kind])
	if edit.has("name"):
		output.append("## @ace_name(\"%s\")" % _quoted(str(edit["name"])))
	if edit.has("category"):
		output.append("## @ace_category(\"%s\")" % _quoted(str(edit["category"])))
	if edit.has("description"):
		output.append("## @ace_description(\"%s\")" % _quoted(str(edit["description"])))
	var params: Dictionary = edit.get("params", {}) as Dictionary
	for param_id: Variant in params:
		var spec: Dictionary = params[param_id] as Dictionary
		var parts: PackedStringArray = PackedStringArray()
		# Fixed key order, so the same spec always renders the same line - the other half of
		# idempotency, since a Dictionary's own iteration order is insertion order.
		for key: String in ["hint", "options", "default"]:
			if spec.has(key):
				parts.append("%s: %s" % [key, _inline(str(spec[key]))])
		if parts.is_empty():
			continue
		output.append("## @ace_param(%s, %s)" % [str(param_id), ", ".join(parts)])
	return output


## Appends a deprecated forwarding shim so a verb that has been RENAMED keeps working.
##
## THE PROBLEM THIS SOLVES, precisely. An ace_id is derived from the member name, so renaming
## `start_wave` to `begin_wave` changes the id from `method:start_wave` and orphans every row that
## already used it. The dangerous part is not the editor - it is that the compiler prefers the
## template BAKED onto the row at apply time over any registry lookup, so an orphaned row still
## emits `$WaveManager.start_wave(3)` with no error and no warning. The sheet compiles green and the
## game breaks at runtime, which is the worst possible place to find out.
##
## An id alias could not fix that: every already-compiled .gd holds the old CALL TEXT and no id at
## all. Only a real member of the old name does. So the shim is the fix, not a workaround:
##
##     ## @ace_deprecated("Renamed to Begin Wave.", "method:begin_wave")
##     ## @ace_name("Start Wave")
##     func start_wave(count: int) -> void:
##         begin_wave(count)
##
## It is APPENDED and nothing else is touched - no existing signature, no body, no call site. That
## is deliberate: rewriting a user's declarations and every reference to them is a different and far
## riskier operation than adding comments, and it is not what this module promises.
static func forwarding_shim(source: String, old_member: String, new_member: String, message: String = "") -> Dictionary:
	var result: Dictionary = {"ok": false, "source": source, "reason": ""}
	var old_name: String = old_member.strip_edges()
	var new_name: String = new_member.strip_edges()
	if old_name.is_empty() or new_name.is_empty() or old_name == new_name:
		result["reason"] = "A shim needs two different member names."
		return result
	var crlf: bool = source.contains("\r\n")
	var lines: PackedStringArray = source.replace("\r\n", "\n").split("\n")
	if find_declaration(lines, "method", old_name) >= 0:
		# Already there (or never renamed) - adding a second one would not parse.
		result["reason"] = "%s already exists in this script." % old_name
		return result
	var target: int = find_declaration(lines, "method", new_name)
	if target < 0:
		result["reason"] = "No function named %s to forward to." % new_name
		return result

	# The shim copies the target's signature verbatim with only the name swapped, so a caller that
	# relied on a default argument keeps working exactly as it did.
	var signature: String = lines[target].strip_edges()
	var open_at: int = signature.find("(")
	var close_at: int = signature.rfind(")")
	if open_at < 0 or close_at < open_at:
		result["reason"] = "Could not read %s's signature." % new_name
		return result
	var argument_text: String = signature.substr(open_at + 1, close_at - open_at - 1)
	var tail: String = signature.substr(close_at + 1).strip_edges()
	var returns_value: bool = not tail.begins_with("-> void") and tail.begins_with("->")
	var call_prefix: String = "return " if returns_value else ""

	var shim: PackedStringArray = PackedStringArray()
	if not lines.is_empty() and not str(lines[lines.size() - 1]).strip_edges().is_empty():
		shim.append("")
	shim.append("")
	var note: String = message.strip_edges()
	if note.is_empty():
		note = "Renamed to %s." % new_name
	shim.append("## @ace_deprecated(\"%s\", \"method:%s\")" % [_quoted(note), new_name])
	shim.append("func %s(%s)%s" % [old_name, argument_text, (" " + tail) if not tail.is_empty() else ":"])
	shim.append("\t%s%s(%s)" % [call_prefix, new_name, ", ".join(_argument_names(argument_text))])

	var rebuilt: PackedStringArray = lines.duplicate()
	rebuilt.append_array(shim)
	var joined: String = "\n".join(rebuilt)
	result["source"] = joined.replace("\n", "\r\n") if crlf else joined
	result["ok"] = true
	return result


## The bare names out of a parameter list, for the forwarding call. Splits only at depth zero, so a
## default like `Vector2(0, 0)` or `Array[int]` does not look like two arguments.
static func _argument_names(argument_text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for index: int in range(argument_text.length()):
		var character: String = argument_text.substr(index, 1)
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		if character == "," and depth == 0:
			names.append(_argument_name(current))
			current = ""
			continue
		current += character
	if not current.strip_edges().is_empty():
		names.append(_argument_name(current))
	var cleaned: PackedStringArray = PackedStringArray()
	for name: String in names:
		if not name.is_empty():
			cleaned.append(name)
	return cleaned


static func _argument_name(argument: String) -> String:
	var text: String = argument.strip_edges()
	for separator: String in [":", "="]:
		var at: int = text.find(separator)
		if at > 0:
			text = text.substr(0, at)
	return text.strip_edges()


static func _is_managed(trimmed_line: String) -> bool:
	var body: String = trimmed_line.trim_prefix("##").strip_edges()
	for annotation: String in MANAGED_ANNOTATIONS:
		if body == annotation or body.begins_with(annotation + "(") or body.begins_with(annotation + " "):
			return true
	return false


## A value safe to sit inside `@ace_name("…")`. The reader trims a surrounding quote pair and has no
## escape, so an inner double quote would end the value early; a newline would end the comment
## entirely. Both are folded rather than rejected, because losing a curly quote is a smaller
## surprise than a dialog refusing a description for punctuation the author cannot see.
static func _quoted(value: String) -> String:
	return _inline(value).replace("\"", "'")


## One line, no leading or trailing space.
static func _inline(value: String) -> String:
	return value.replace("\r", " ").replace("\n", " ").strip_edges()


static func _leading_whitespace(line: String) -> String:
	return line.substr(0, line.length() - line.lstrip(" \t").length())


static func _escaped(member: String) -> String:
	return member.replace("\\", "\\\\").replace(".", "\\.")
