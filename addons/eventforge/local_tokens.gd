# Godot EventSheets - the short token a row bakes into the locals it declares.
#
# A verb whose template declares a local of its own carries `{uid}` in that template, and the dock
# bakes it to eight hex digits the moment the row is applied - `__peer_a3f81c02`, `__spawn_1b0c77de`.
# The token is what keeps two copies of the same row from declaring the same variable twice in one
# function body, so it has exactly one job: to be unlike every other one.
#
# TWO GUARDS, AND THEY ARE DIFFERENT KINDS OF GUARD.
#
#  1. MINTING CONSULTS THE INDEX. A fresh token is drawn against every token the project's own
#     scripts already hold, not just against the ones this session minted. Two rows applied a year
#     apart in two files can therefore never collide, and - the point of the guard - a collision that
#     does turn up cannot have come from ordinary work. It came from two branches minting in
#     parallel and a merge bringing both in, which is a thing a person has to be told about rather
#     than a thing a random draw can prevent.
#
#  2. AFTER A MERGE, THE DUPLICATE IS NAMED. Two rows declaring the same token in one scope is a file
#     Godot refuses to parse, loudly and at the worst moment. `duplicates_in` reads it off the text
#     first and says it plainly, and the re-mint below is the one-click answer - an ordinary
#     undoable sheet edit that rewrites ONE of the two tokens and leaves everything else alone.
#
# THE INDEX IS A QUESTION, NEVER A WRITE. Nothing here rewrites a file, caches into res://, or
# remembers anything between sessions. The index is a listing of what is already on disk, built once
# per editor session because the walk is the expensive half (measured at 0.4 s over 1,300 scripts and
# 11 MB of text, of which 177 files even contain a `__`), and dropped whenever the filesystem moves.
#
# PURE + STATIC apart from that one cache, so every rule below is pinned headless.
@tool
class_name EventSheetLocalTokens
extends RefCounted

## The shape of a baked local, frozen because it is already baked into shipped files: two leading
## underscores, a lowercase prefix, an underscore, and eight hex digits. Group 1 is the token.
const TOKEN_PATTERN := "__[a-z_]+_([0-9a-f]{8})\\b"

## The same shape as a DECLARATION - the `var` in front is what makes an occurrence the place the
## name is introduced rather than one of the places it is used. Group 1 is the whole local name and
## group 2 the token.
##
## ANNOTATIONS IN FRONT OF IT ARE STILL A DECLARATION. `@export var __peer_a3f81c02` introduces the
## name exactly as the bare form does, and a pattern that only knew the bare form reported such a
## file clean while Godot refused to parse it - which is the one state this whole check exists for.
const DECLARATION_PATTERN := "^\\s*(?:@[A-Za-z_][A-Za-z_0-9]*(?:\\([^)]*\\))?\\s+)*var\\s+(__[a-z_]+_([0-9a-f]{8}))\\b"

## The id the duplicate finding is filed under, and the id its chip is offered against. Frozen
## alongside the wording, like every other check id: the inbox and the tests address it by this.
const CHECK_DUPLICATE_TOKEN := "duplicate-local-token"

## What a declaration outside any function is said to be in. A stateful condition's member sits in
## the class body, and "in the class body" is what a reader would call that place.
const CLASS_BODY_SCOPE := "the class body"

## How wide a token is, and the alphabet it is drawn from - the mint's own contract, held here beside
## the pattern that reads it so the two can never drift apart.
const TOKEN_WIDTH: int = 8

# Compiled once for the session: both patterns are asked of every line of every script in the
# project, and rebuilding a RegEx per file was the whole cost of the walk.
static var _token_re: RegEx = null
static var _declaration_re: RegEx = null

## token -> true for every token the project's own scripts already hold, and whether it has been
## built. Session-scoped: it is a listing of files on disk, so it is dropped whenever the editor says
## the filesystem moved, exactly like the script listing the Doctor keeps.
static var _index: Dictionary = {}
static var _index_built: bool = false


## The token reader. Every token in one text, sorted and without repeats - what the index is built
## from and what a test hands in by hand.
static func tokens_in(source: String) -> PackedStringArray:
	var seen: Dictionary = {}
	for hit: RegExMatch in _tokens().search_all(source):
		seen[hit.get_string(1)] = true
	var out: PackedStringArray = PackedStringArray()
	for token: Variant in seen.keys():
		out.append(str(token))
	out.sort()
	return out


## Every place this text INTRODUCES a baked local, in file order:
## {token, name, scope, line} - `line` 1-based, `scope` the enclosing function's name or
## `CLASS_BODY_SCOPE`.
##
## Scope is read the way GDScript scopes actually work for this purpose: a `func` opens a body, and
## everything indented deeper than that `func` belongs to it. That is enough, because a baked local
## is only ever written by a template into a function body or by a stateful condition into the class
## body - the two places this plugin puts one.
##
## THE INDENT OF THE `func` IS WHAT CLOSES ITS BODY, not column zero. An inner class indents its own
## functions, and a reader that only recognised a `func` at the outermost indent never opened a scope
## for any of them - so every local an inner class declared was filed under the class body, where two
## of its methods each declaring one read as a doubled name in a single scope. Names are qualified
## with the inner class they are in for the same reason: two inner classes may each have a `tick`,
## and they are two different scopes.
static func declarations_in(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var scope: String = CLASS_BODY_SCOPE
	# The indent the current scope's `func` was written at, and -1 while there is no open body. A line
	# at that indent or shallower has left the body behind it.
	var scope_indent: int = -1
	var inner_class: String = ""
	var line_number: int = 0
	for line: String in source.split("\n"):
		line_number += 1
		var without_indent: String = line.lstrip("\t ")
		var indent: int = line.length() - without_indent.length()
		if without_indent.begins_with("func ") or without_indent.begins_with("static func "):
			scope = _function_name(without_indent)
			if not inner_class.is_empty():
				scope = "%s.%s" % [inner_class, scope]
			scope_indent = indent
			continue
		# A line back at the scope's own indent or shallower has left the body behind it - another
		# declaration, an annotation, a line of the class. A blank line is not a scope change (bodies
		# are full of them), so only lines with something on them close one.
		if indent <= scope_indent and not without_indent.strip_edges().is_empty():
			scope = CLASS_BODY_SCOPE
			scope_indent = -1
		if indent == 0 and without_indent.begins_with("class "):
			inner_class = without_indent.trim_prefix("class ").split(":")[0].split(" ")[0].strip_edges()
		elif indent == 0 and not without_indent.strip_edges().is_empty():
			inner_class = ""
		var hit: RegExMatch = _declarations().search(line)
		if hit == null:
			continue
		found.append({
			"token": hit.get_string(2),
			"name": hit.get_string(1),
			"scope": scope,
			"line": line_number,
		})
	return found


## The state a merge leaves behind: one entry per token declared MORE THAN ONCE in one scope, as
## {token, name, scope, lines: PackedInt32Array}. Sorted by scope then token, so two machines reading
## the same file print the same list.
##
## Same scope is the whole rule, and it is the rule because it is Godot's: two locals of the same
## name in two different function bodies are two different variables and nothing is wrong. Two in one
## body is a file that will not parse.
static func duplicates_in(source: String) -> Array[Dictionary]:
	var by_place: Dictionary = {}
	for declaration: Dictionary in declarations_in(source):
		var key: String = "%s|%s" % [str(declaration["scope"]), str(declaration["token"])]
		if not by_place.has(key):
			by_place[key] = {
				"token": str(declaration["token"]),
				"name": str(declaration["name"]),
				"scope": str(declaration["scope"]),
				"lines": PackedInt32Array(),
			}
		# Read out, append, put back. A PackedInt32Array is a VALUE in GDScript, so appending to the
		# one a Dictionary hands back appends to a copy and the entry never grows - which reported
		# every file as clean while the declarations under it were being read perfectly.
		var lines: PackedInt32Array = by_place[key]["lines"] as PackedInt32Array
		lines.append(int(declaration["line"]))
		by_place[key]["lines"] = lines
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in by_place.keys():
		keys.append(str(key))
	keys.sort()
	var out: Array[Dictionary] = []
	for key: String in keys:
		var entry: Dictionary = by_place[key]
		if (entry["lines"] as PackedInt32Array).size() > 1:
			out.append(entry)
	return out


## The words, in one place, so the Doctor's line and anything else that says this say it once.
## Plain first and explained second: the reader needs to know WHICH token and WHERE before they need
## to know why it matters.
static func duplicate_message(entry: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line_number: int in (entry.get("lines", PackedInt32Array()) as PackedInt32Array):
		lines.append(str(line_number))
	return "%s rows both declare %s in %s (lines %s). Godot refuses a file that declares one name twice, so this will not run - it is two branches that minted the same token and a merge that brought both in. Re-mint one of them and both rows go on working." % [
		_counted(lines.size()), str(entry.get("name", "")), str(entry.get("scope", "")),
		", ".join(lines)]


## "Two" / "Three" / "5" - the count as a reader would open a sentence with it. Two is the case that
## happens, so it is the one that gets a word.
static func _counted(count: int) -> String:
	match count:
		2:
			return "Two"
		3:
			return "Three"
	return str(count)


# ── The index the mint draws against ────────────────────────────────────────────────────


## Every token held by the files at `paths`, as a token -> true set. Pure over its argument, so the
## audit, the editor and a test all build the index the same way over whatever corpus they mean.
##
## The `__` test in front of the regex is what makes the walk affordable: the pattern cannot match a
## text with no double underscore in it, and in a real project almost no file has one.
static func index_over(paths: PackedStringArray) -> Dictionary:
	var index: Dictionary = {}
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("__"):
			continue
		for token: String in tokens_in(source):
			index[token] = true
	return index


## The project's own index, built once per session and held until the filesystem moves. The corpus is
## the project's scripts - the sheets a person writes - and not the plugin's own source, which is
## exactly the listing the Doctor already keeps for the same reason.
static func project_index() -> Dictionary:
	if _index_built:
		return _index
	_index = index_over(EventSheetProjectDoctor.all_project_scripts())
	_index_built = true
	return _index


## True when some file in the project already declares a local with this token. The one question the
## mint asks.
static func is_taken(token: String) -> bool:
	return project_index().has(token)


## Records a token as taken WITHOUT re-walking - what the mint calls after drawing one, so the next
## draw in the same session cannot repeat it even before anything is saved.
static func remember(token: String) -> void:
	project_index()[token] = true


## Drops the index, so the next ask lists the project again. Called from the editor's filesystem hook
## for the same reason the Doctor's script listing is, and by a test that has finished with a seeded
## one.
static func clear_index() -> void:
	_index = {}
	_index_built = false


## An index of exactly these tokens and nothing else - how a test pins the exclusion without a walk
## of the whole project standing between the rule and the assertion.
static func seed_index(tokens: PackedStringArray) -> void:
	_index = {}
	for token: String in tokens:
		_index[token] = true
	_index_built = true


# ── The re-mint ─────────────────────────────────────────────────────────────────────────


## Every baked field of one sheet that carries `token`, in reading order:
## {row, field, event} - `row` the ACE resource, `field` the property name, `event` the EventRow it
## sits in. What the re-mint rewrites, and what the receipt counts.
##
## FOUR FIELDS AND NOT THREE. A stateful condition bakes its token into its declaration, its
## template, its prelude, its on-true and its on-exit, and a re-mint that missed one of them would
## leave a row half renamed - which is worse than the duplicate, because it compiles.
static func carriers(sheet: EventSheetResource, token: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or token.strip_edges().is_empty():
		return found
	_walk_carriers(sheet.events, token, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk_carriers(event_function.events if not event_function.events.is_empty() \
				else event_function.rows, token, found)
	return found


## The baked fields a token can live in, in the order a reader would list them. Frozen alongside the
## bake sites in the dock: a field added there has to be added here, or a re-mint leaves half a row.
const BAKED_FIELDS: PackedStringArray = ["member_declaration", "codegen_template",
	"codegen_prelude", "codegen_on_true", "codegen_on_exit"]


static func _walk_carriers(items: Array, token: String, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_carriers(EventSheetGroupFacts.children(item as EventGroup), token, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.conditions + event_row.actions:
			if not (entry is Resource):
				continue
			for field: String in BAKED_FIELDS:
				var value: Variant = (entry as Resource).get(field)
				if value is String and (value as String).contains(token):
					found.append({"row": entry, "field": field, "event": event_row})
		_walk_carriers(event_row.sub_events, token, found)


## Which ROWS of this sheet carry the token, in reading order and without repeats. The re-mint keeps
## the first and rewrites the rest, so this is the list that decides what "one of them" means.
static func rows_carrying(sheet: EventSheetResource, token: String) -> Array:
	var rows: Array = []
	for carrier: Dictionary in carriers(sheet, token):
		if not rows.has(carrier["row"]):
			rows.append(carrier["row"])
	return rows


## Re-mints the token on every row carrying it EXCEPT THE FIRST, which is what makes the file legal
## again while changing as little as possible: the row that was there keeps the name it had, and the
## one the merge brought in gets a name of its own.
##
## `fresh` supplies the new token (the dock hands in its own mint, a test hands in a fixed one), and
## is asked once per rewritten ROW - two rows that collided get two different names, not one shared
## new one.
##
## Returns one receipt per rewritten row: {before, after, fields} - the local's name as it was, the
## name it now has, and how many baked fields moved. Empty when there was nothing to do, which is how
## a caller that repairs in a loop ends.
static func remint(sheet: EventSheetResource, token: String, fresh: Callable) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	if sheet == null or not fresh.is_valid():
		return receipts
	var rows: Array = rows_carrying(sheet, token)
	if rows.size() < 2:
		return receipts
	var all_carriers: Array[Dictionary] = carriers(sheet, token)
	for index: int in range(1, rows.size()):
		var row: Variant = rows[index]
		var new_token: String = str(fresh.call())
		var moved: int = 0
		var before: String = ""
		var after: String = ""
		for carrier: Dictionary in all_carriers:
			if carrier["row"] != row:
				continue
			var field: String = str(carrier["field"])
			var value: String = str((row as Resource).get(field))
			if before.is_empty():
				before = _local_name(value, token)
				after = before.replace(token, new_token)
			(row as Resource).set(field, value.replace(token, new_token))
			moved += 1
		receipts.append({"before": before, "after": after, "fields": moved})
	return receipts


## The full local name a token appears in, read out of one baked field - `__peer_a3f81c02` rather
## than the eight digits on their own, because the name is what the reader sees in the file and what
## Godot's own error names.
static func _local_name(value: String, token: String) -> String:
	for hit: RegExMatch in _tokens().search_all(value):
		if hit.get_string(1) == token:
			return hit.get_string(0)
	return "__" + token


static func _function_name(line: String) -> String:
	var without_static: String = line.trim_prefix("static ").trim_prefix("func ").strip_edges()
	var open_bracket: int = without_static.find("(")
	return without_static.substr(0, open_bracket).strip_edges() if open_bracket > 0 \
		else without_static


static func _tokens() -> RegEx:
	if _token_re == null:
		_token_re = RegEx.create_from_string(TOKEN_PATTERN)
	return _token_re


static func _declarations() -> RegEx:
	if _declaration_re == null:
		_declaration_re = RegEx.create_from_string(DECLARATION_PATTERN)
	return _declaration_re
