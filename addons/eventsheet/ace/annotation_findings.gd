# Godot EventSheets - what a script's own comments say that nothing reads.
#
# A script becomes picker rows through the `##` lines above its members, and every one of those lines
# is read by exact spelling: a word one letter off is not an error anywhere, it is simply prose, and a
# slot written with a typo'd key is dropped without a sound. The author only finds out when the row
# reads wrong, and has nothing to point at.
#
# This reads a script's SOURCE and names each such line, with the line number and - where a close
# spelling exists - the word that was probably meant. It is a plain scan, additive and quiet: it
# changes nothing about how a script is read, it never writes, and it never loads the script. Every
# sentence it produces says what happened and what to do, in the words the author already sees in
# their own file.
#
# No class_name, matching the scripts beside it that a boot never needs: callers preload it by path
# at the moment somebody asks.
@tool
extends RefCounted

## The keys `@ace_param(name, key: value, ...)` reads. Anything else in that position is dropped.
const PARAM_KEYS: PackedStringArray = ["hint", "options", "default", "default_word", "default_code",
	"autocomplete", "desc"]

## How far a spelling may be from a known word and still be offered as "did you mean". Two letters
## catches a swap, a missing letter or a doubled one, and stays far from unrelated words.
const MAX_DISTANCE: int = 2

const KIND_NEAR_MISS: String = "near_miss"
const KIND_PARAM_KEY: String = "param_key"
const KIND_PARAM_COLON: String = "param_colon"
const KIND_BLOCK_CUT: String = "block_cut"
const KIND_UNTYPED: String = "untyped"

const SpecText := preload("res://addons/eventforge/registration/annotation_spec_text.gd")


## Every finding in one script's source, in file order. Each is
## {"kind", "line" (1-based), "text" (what the line says), "member" (the function, signal or variable
## the block belongs to, "" when none), "suggestion" ("" when nothing is close)}.
## An untyped function is named when its own block carries a word, or when `all_untyped` says every
## public function of the script will be published.
static func read(source: String, all_untyped: bool = false) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var untyped_head: RegEx = RegEx.create_from_string(r"^func\s+([a-zA-Z][A-Za-z0-9_]*)\s*\([^)]*\)\s*:")
	var has_words: bool = false
	var cut_line: int = 0
	var cut_text: String = ""
	var line_number: int = 0
	for raw_line: String in source.split("\n"):
		line_number += 1
		var stripped: String = raw_line.strip_edges()
		if stripped.is_empty():
			continue
		if stripped.begins_with("##") or stripped.begins_with("@ace_"):
			var directive: String = stripped.trim_prefix("##").strip_edges() if stripped.begins_with("##") else stripped
			if directive.begins_with("@"):
				_read_directive(directive, line_number, findings)
				if directive.begins_with("@ace_"):
					has_words = true
			continue
		if stripped.begins_with("#"):
			# The annotation block above a member is cleared by any line that is not a `##` line, so a
			# single-hash comment between the two cuts the words off from the member they describe.
			if has_words and cut_line == 0:
				cut_line = line_number
				cut_text = stripped
			continue
		var member: String = _member_of(stripped)
		if not member.is_empty():
			if cut_line > 0:
				findings.append({"kind": KIND_BLOCK_CUT, "line": cut_line, "text": cut_text,
					"member": member, "suggestion": ""})
			if has_words or all_untyped:
				var untyped: RegExMatch = untyped_head.search(stripped)
				if untyped != null and not stripped.begins_with("func _"):
					findings.append({"kind": KIND_UNTYPED, "line": line_number, "text": stripped,
						"member": untyped.get_string(1), "suggestion": ""})
		if not stripped.begins_with("@") or not member.is_empty():
			has_words = false
			cut_line = 0
			cut_text = ""
	return findings


## One sentence for a finding, translated, saying what is wrong and what to do about it.
static func sentence(finding: Dictionary) -> String:
	var line: int = int(finding.get("line", 0))
	var text: String = str(finding.get("text", ""))
	var member: String = str(finding.get("member", ""))
	var suggestion: String = str(finding.get("suggestion", ""))
	match str(finding.get("kind", "")):
		KIND_NEAR_MISS:
			if suggestion.is_empty():
				return EventSheetL10n.translate("Line %d starts with %s, which is not a word this reads, so it is only a note. Check the spelling.") % [line, text]
			return EventSheetL10n.translate("Line %d starts with %s, which is not a word this reads, so it is only a note. Did you mean %s?") % [line, text, suggestion]
		KIND_PARAM_KEY:
			if suggestion.is_empty():
				return EventSheetL10n.translate("Line %d: %s is not a setting a parameter line reads, so it is left out. It reads hint, options, default, default_word, default_code, autocomplete and desc.") % [line, text]
			return EventSheetL10n.translate("Line %d: %s is not a setting a parameter line reads, so it is left out. Did you mean %s?") % [line, text, suggestion]
		KIND_PARAM_COLON:
			return EventSheetL10n.translate("Line %d: %s has no colon, so it is left out. Write it as key: value.") % [line, text]
		KIND_BLOCK_CUT:
			return EventSheetL10n.translate("Line %d is a # comment between the words above it and %s, so %s reads with none of them. Start that line with ## instead.") % [line, member, member]
		KIND_UNTYPED:
			return EventSheetL10n.translate("%s has no return type, so it reads as an action. Add -> bool to make it a condition, or a type to make it an expression.") % member
	return ""


## The known word a spelling is closest to, or "" when none is within reach. `known` is a set of
## words; ties go to the alphabetically first so the answer is the same on every machine.
static func closest(word: String, known: Array) -> String:
	var best: String = ""
	var best_distance: int = MAX_DISTANCE + 1
	var sorted_words: Array = known.duplicate()
	sorted_words.sort()
	for candidate: Variant in sorted_words:
		var distance: int = distance_between(word, str(candidate))
		if distance < best_distance:
			best_distance = distance
			best = str(candidate)
	return best


## Edit distance between two short words (insert, delete, replace, and a swap of neighbours as one).
static func distance_between(left: String, right: String) -> int:
	var rows: int = left.length() + 1
	var columns: int = right.length() + 1
	var table: Array = []
	for row: int in range(rows):
		var cells: Array = []
		cells.resize(columns)
		cells.fill(0)
		cells[0] = row
		table.append(cells)
	for column: int in range(columns):
		(table[0] as Array)[column] = column
	for row: int in range(1, rows):
		for column: int in range(1, columns):
			var same: int = 0 if left[row - 1] == right[column - 1] else 1
			var best: int = mini(mini((table[row - 1] as Array)[column] + 1, (table[row] as Array)[column - 1] + 1),
				(table[row - 1] as Array)[column - 1] + same)
			if row > 1 and column > 1 and left[row - 1] == right[column - 2] and left[row - 2] == right[column - 1]:
				best = mini(best, (table[row - 2] as Array)[column - 2] + 1)
			(table[row] as Array)[column] = best
	return (table[rows - 1] as Array)[columns - 1]


## The word at the start of one directive, and what is wrong with it if anything.
static func _read_directive(directive: String, line_number: int, findings: Array[Dictionary]) -> void:
	var word: String = _leading_word(directive)
	var known: Array = EventSheetSemanticAnalyzer.KNOWN_ANNOTATIONS.keys()
	if not EventSheetSemanticAnalyzer.KNOWN_ANNOTATIONS.has(word):
		# Only a word that could plausibly have been meant for one of ours is worth a line: an
		# `@export` in a doc comment, or a mention of `@tool`, is just prose.
		var near: String = closest(word, known)
		if word.begins_with("@ace_") or not near.is_empty():
			findings.append({"kind": KIND_NEAR_MISS, "line": line_number, "text": word, "member": "",
				"suggestion": near})
		return
	if word == "@ace_param":
		_read_param_spec(directive, line_number, findings)


## `@ace_param(amount, hint: expression, defualt: 5)`: the segments after the name must each be
## `key: value` with a key the line reads.
static func _read_param_spec(directive: String, line_number: int, findings: Array[Dictionary]) -> void:
	var open_at: int = directive.find("(")
	var close_at: int = directive.rfind(")")
	if open_at < 0 or close_at <= open_at:
		return
	var segments: Array[String] = []
	for part: String in SpecText.split_outside_quotes(directive.substr(open_at + 1, close_at - open_at - 1), ","):
		segments.append(part)
	for index: int in range(1, segments.size()):
		var segment: String = segments[index].strip_edges()
		if segment.is_empty():
			continue
		var colon: int = segment.find(":")
		if colon < 0:
			findings.append({"kind": KIND_PARAM_COLON, "line": line_number, "text": segment, "member": "",
				"suggestion": ""})
			continue
		var key: String = segment.substr(0, colon).strip_edges()
		if not PARAM_KEYS.has(key):
			findings.append({"kind": KIND_PARAM_KEY, "line": line_number, "text": key, "member": "",
				"suggestion": closest(key, Array(PARAM_KEYS))})


## `@ace_name("Hurt")` -> `@ace_name`; the whole first word, including the `@`.
static func _leading_word(directive: String) -> String:
	var word: String = "@"
	for index: int in range(1, directive.length()):
		var character: String = directive.substr(index, 1)
		if character == "_" or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") \
				or (character >= "0" and character <= "9"):
			word += character
		else:
			break
	return word


## The name a member line declares, or "" when the line declares none the analyzer attaches a block to.
static func _member_of(stripped: String) -> String:
	for head: String in ["func ", "signal "]:
		if stripped.begins_with(head):
			var rest: String = stripped.trim_prefix(head).strip_edges()
			var paren: int = rest.find("(")
			return (rest.substr(0, paren) if paren >= 0 else rest).strip_edges()
	if stripped.begins_with("@export") or stripped.begins_with("var "):
		var at: int = stripped.find("var ")
		if at >= 0:
			var rest: String = stripped.substr(at + 4).strip_edges()
			for separator: String in [":", "=", " "]:
				var found: int = rest.find(separator)
				if found != -1:
					rest = rest.substr(0, found)
					break
			return rest.strip_edges()
	return ""
