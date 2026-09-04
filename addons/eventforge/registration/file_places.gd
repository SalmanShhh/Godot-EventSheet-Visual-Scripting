# EventForge - the PLACES a path can name, and the one reading of them.
#
# Godot gives a game exactly two places to keep files, and confusing them is the single commonest way
# a project that runs perfectly in the editor fails on the first machine it is sent to:
#
#     res://   the game's OWN files, packed into the build. READ-ONLY once exported. Writing here
#              works in the editor - the project is a folder on your disk - and fails in every
#              exported build, silently, because the pack is not a folder any more.
#     user://  the PLAYER'S folder. Writable, one per player, and it survives the game being
#              updated, which is why saves, settings and logs all belong here.
#
# Nothing in Godot says this out loud at the moment somebody types a path, so this file is what says
# it: every path field of the file vocabulary carries a muted lead naming its place, the Parameters
# strip says what each place allows and where user:// really is on each desktop platform, and the
# Doctor reads the same two answers when it looks for the export trap.
#
# ONE READING, MANY READERS. The field lead, the help strip, both Doctor checks, both one-click
# fixes and the tests all ask the functions here. A second opinion about what `res://` means is how a
# report and a row end up disagreeing about the same string.
#
# IT ONLY EVER READS THE TEXT. A path field holds a GDScript expression - `"user://save.dat"` today,
# `"user://slot_%d.dat" % slot` tomorrow, a variable the day after - so the place is read off the
# LITERAL when there is one and left UNKNOWN when there is not. An expression whose place cannot be
# read is not an expression with a bad place: it is one this file has nothing to say about, and
# saying nothing is the honest answer. Every warning below is therefore raised on a literal only.
@tool
class_name EventForgeFilePlaces
extends RefCounted

## The places, as stable ids. Never translated and never renamed - the Doctor's findings, the
## quick-fix ids and the tests all address a place by these.
const PLACE_USER := "user"
const PLACE_RES := "res"
const PLACE_ABSOLUTE := "absolute"
const PLACE_UNKNOWN := "unknown"

## The two schemes Godot itself understands.
const USER_SCHEME := "user://"
const RES_SCHEME := "res://"

## The verbs that WRITE, with the parameters that carry the path each one writes to. A write aimed at
## res:// is the export trap; a read aimed at res:// is exactly right and is never reported. Frozen
## alongside the ace_ids themselves: a fix addresses a row through this table.
## WHICH VERBS WRITE IS THE ONE THING NO HINT CAN SAY. A path field says it is a path; nothing about
## it says whether the row reads it or overwrites it, and the two answers are the whole difference
## between the export trap and a perfectly correct row. So this stays a written-down table, and the
## suite gates it against what the templates actually compile to: a verb whose emitted line makes a
## write call and carries a path field must be in here.
const WRITE_SHAPED: Dictionary = {
	"WriteTextFile": ["path"],
	"AppendTextFile": ["path"],
	"WriteTextFileInFolder": ["path"],
	"DeleteFile": ["path"],
	"MoveFile": ["to"],
	"CopyFile": ["to"],
	"MakeDir": ["path"],
	"RemoveDir": ["path"],
	# The engine's own CSV writer, and the two archive verbs. A pack writes into the folder it
	# unpacks into and reads the archive it unpacks; a pack row writes the archive and reads the
	# folder, which is why each names exactly one of its two paths here.
	"WriteFileTable": ["path"],
	"PackFolderIntoZip": ["archive"],
	"UnpackZipIntoFolder": ["folder"],
	# Saving a branch of the running game as a scene file is a write like any other, and the export
	# trap catches it exactly the way it catches a text file: a level the player built, written to
	# res://, is written in the editor and silently nowhere in the exported build.
	"SaveBranchAsSceneFile": ["path"],
}

## The hint every path field carries. The ONE mark a path field is known by - the field lead, the
## files band and the walk below all ask this and nothing else.
const PATH_HINT := "file_path"

## The path parameters of the verbs this file must know about even with no registry to ask: the
## OVERRIDE list, not the answer. `path_params_of` derives its answer from the verb's own descriptor
## by the hint above, so a path field a pack ships is seen the day the pack ships and a verb added
## tomorrow needs no entry here; this table is what answers when the registry has nothing (a check
## run over text alone, a fixture built with no descriptors loaded).
const PATH_PARAMS: Dictionary = {
	"FileExists": ["path"],
	"ReadTextFile": ["path"],
	"ReadTextFileOr": ["path"],
	"GetFileSize": ["path"],
	"WriteTextFile": ["path"],
	"WriteTextFileInFolder": ["path"],
	"AppendTextFile": ["path"],
	"DeleteFile": ["path"],
	"CopyFile": ["from", "to"],
	"MoveFile": ["from", "to"],
	"DirExists": ["path"],
	"MakeDir": ["path"],
	"RemoveDir": ["path"],
	"ListFiles": ["path"],
	"ListDirs": ["path"],
	"OpenUserDataFolder": ["path"],
	"FreeFilePath": ["path"],
	"ShowInFileManager": ["path"],
}

## The calls a WRITE is spelled with in emitted code, for the text sweep the Doctor runs over the
## project's own scripts. Read off the emitted line rather than off a row, for the same reason the
## release-build console check is: the line is there whoever typed it.
const WRITE_CALLS: PackedStringArray = [
	"FileAccess.open(", "DirAccess.remove_absolute(", "DirAccess.rename_absolute(",
	"DirAccess.copy_absolute(", "DirAccess.make_dir_recursive_absolute(",
	# The engine's own resource writer. A packed scene or a `.tres` written to res:// is the export
	# trap said one more way - it lands in the project folder in the editor and nowhere at all in the
	# exported build - and Save Branch As Scene File is spelled with exactly this call.
	"ResourceSaver.save(",
]

## The archive writer, and the call that names the file it writes. An archive written to res:// is
## the export trap said one more way - and the files band already reads a packing row as WRITTEN off
## this very class, so a check that could not see it would be a second reading of the same row.
##
## A PACKER IS A NAME FIRST AND A WRITE SECOND: `var zip := ZIPPacker.new()` on one line and
## `zip.open(path)` on another, whatever the name is. So it is followed by the name rather than
## matched as one call text, which is also what keeps a ZIPReader's identical `open(` out of it.
const PACKER_CLASS := "ZIPPacker.new("
const OPEN_CALL := ".open("

## A FOLDER HANDLE IS THE SAME STORY AS A PACKER. `DirAccess.open(path)` answers with a handle whose
## own methods act on that folder, so the place is written on one line and the write happens on
## another - or on the same one, chained. Opening a folder is a READ until one of the methods below is
## asked of the handle: listing the game's own files is what `res://` is for.
const DIR_OPEN_CALL := "DirAccess.open("
const DIR_HANDLE_WRITES: PackedStringArray = [
	".make_dir(", ".make_dir_recursive(", ".remove(", ".rename(", ".copy(",
]

## The call a plain read is spelled with, and the question that guards one.
const READ_CALL := "FileAccess.get_file_as_string("
const EXISTS_CALL := "FileAccess.file_exists("


## The place one path expression names. UNKNOWN for anything that is not a plain quoted literal -
## a built path is a path this file has nothing to say about, and guessing at one would put a
## warning on a correct row.
static func place_of(path_expression: String) -> String:
	var literal: String = literal_of(path_expression)
	if literal.is_empty():
		return PLACE_UNKNOWN
	if literal.begins_with(USER_SCHEME):
		return PLACE_USER
	if literal.begins_with(RES_SCHEME):
		return PLACE_RES
	if is_absolute_os_path(literal):
		return PLACE_ABSOLUTE
	return PLACE_UNKNOWN


## The quoted string an expression IS, or "" when it is anything else. A concatenation
## (`"user://" + name`) is deliberately not a literal: its place is knowable, but its path is not,
## and every reader here needs both.
static func literal_of(path_expression: String) -> String:
	var text: String = path_expression.strip_edges()
	if text.length() < 2:
		return ""
	var quote: String = text.substr(0, 1)
	if quote != "\"" and quote != "'":
		return ""
	if not text.ends_with(quote):
		return ""
	var inner: String = text.substr(1, text.length() - 2)
	return "" if inner.contains(quote) else inner


## The place a path expression BEGINS in, even when the rest of it is built at run time. `"user://"
## + slot_name` is a user:// path by every reading that matters, and the muted lead under the field
## should say so rather than falling silent the moment somebody joins two strings.
static func leading_place_of(path_expression: String) -> String:
	var known: String = place_of(path_expression)
	if known != PLACE_UNKNOWN:
		return known
	var text: String = path_expression.strip_edges()
	if text.begins_with("\"%s" % USER_SCHEME) or text.begins_with("'%s" % USER_SCHEME):
		return PLACE_USER
	if text.begins_with("\"%s" % RES_SCHEME) or text.begins_with("'%s" % RES_SCHEME):
		return PLACE_RES
	return PLACE_UNKNOWN


## True for a path rooted in one computer's own filesystem: a Windows drive letter, a UNC share, or a
## POSIX root. None of these exist on the machine the game is sent to.
static func is_absolute_os_path(literal: String) -> bool:
	var text: String = literal.strip_edges()
	if text.length() < 2:
		return false
	if text.begins_with("//") or text.begins_with("\\\\"):
		return true
	if text.begins_with("/") or text.begins_with("\\"):
		return true
	var drive: String = text.substr(0, 1)
	var is_letter: bool = drive.to_lower() != drive.to_upper()
	return is_letter and text.substr(1, 2) in [":/", ":\\"]


## The muted lead one path field wears - the place, and what that place allows, in one line. This is
## the sentence a reader meets before they meet the trap, which is the whole point of it.
static func lead_for(place: String) -> String:
	match place:
		PLACE_USER:
			return EventSheetL10n.translate("user:// - the player's folder: writable, one per player, survives updates.")
		PLACE_RES:
			return EventSheetL10n.translate("res:// - the game's own files: READ-ONLY once exported.")
		PLACE_ABSOLUTE:
			return EventSheetL10n.translate("an absolute path: this folder exists on one computer and nowhere else.")
	return ""


## The lead one written path field shows, read off what is in the box right now.
static func lead_for_path(path_expression: String) -> String:
	return lead_for(leading_place_of(path_expression))


## Where user:// really is, per desktop platform. The question every developer asks the first time a
## save goes missing, answered in the strip rather than in a search engine. Godot's own layout, and
## `<project>` is the project's name as Project Settings spells it.
static func where_user_lives() -> String:
	return EventSheetL10n.translate("user:// is a real folder on the player's machine: %APPDATA%\\Godot\\app_userdata\\<project> on Windows, ~/Library/Application Support/Godot/app_userdata/<project> on macOS, ~/.local/share/godot/app_userdata/<project> on Linux. Open the player's data folder opens it while the game runs.")


## The same path, rewritten under user://. A res:// path keeps everything after the scheme; an
## absolute path keeps its file name only, because the folders above it are one computer's own.
## Returns "" when there is nothing to rewrite, so a caller never offers a fix that changes nothing.
static func under_user(literal: String) -> String:
	var text: String = literal.strip_edges()
	if text.begins_with(USER_SCHEME):
		return ""
	if text.begins_with(RES_SCHEME):
		return USER_SCHEME + text.substr(RES_SCHEME.length())
	if is_absolute_os_path(text):
		var file_name: String = text.replace("\\", "/").get_file()
		return "" if file_name.is_empty() else USER_SCHEME + file_name
	return ""


## The same path, rewritten under res://. The other honest answer for an absolute path: a file the
## GAME ships with belongs in the project, and only the reader knows which of the two they meant.
static func under_res(literal: String) -> String:
	var text: String = literal.strip_edges()
	if text.begins_with(RES_SCHEME) or text.begins_with(USER_SCHEME):
		return ""
	if not is_absolute_os_path(text):
		return ""
	var file_name: String = text.replace("\\", "/").get_file()
	return "" if file_name.is_empty() else RES_SCHEME + file_name


## A rewritten path back in the quotes the field held it in, so a fix puts an expression back where
## it found one rather than a bare string.
static func requote(original_expression: String, new_literal: String) -> String:
	var text: String = original_expression.strip_edges()
	var quote: String = text.substr(0, 1) if text.begins_with("'") else "\""
	return "%s%s%s" % [quote, new_literal, quote]


## The line a read compiles to, guarded or not - the ONE place the guarded shape is spelled, so the
## verb, the Doctor's respelling fix and the tests can never write three different ternaries.
##
## An empty fallback is not a fallback: it is a read with none asked for, and it emits the plain call.
## That is what makes the second parameter a default argument rather than a clause on the sentence -
## leaving it blank leaves the sentence exactly as it was.
##
## THE GUARDED FORM WEARS ITS OWN BRACKETS. A read answers inside a parameter slot - beside a `+`, on
## one side of a `==`, in the middle of somebody's own sentence - and a bare `a if b else c` spliced
## between two operators binds them INTO the branches: `read if exists else "" == "x"` is the file's
## text, not a comparison. That is a wrong answer rather than a parse error, so nothing would ever
## have said so. The plain read needs no brackets and gets none: it is one call.
static func guarded_read(path_expression: String, fallback_expression: String) -> String:
	var path: String = path_expression.strip_edges()
	var fallback: String = fallback_expression.strip_edges()
	if fallback.is_empty():
		return "FileAccess.get_file_as_string(%s)" % path
	return "(FileAccess.get_file_as_string(%s) if FileAccess.file_exists(%s) else %s)" % [
		path, path, fallback]


## The prelude a write asks for when its path has folders in it: the one line that makes them, which
## Godot will not do on the way to opening a file. Emitted ABOVE the write and shown in the row's own
## echo - a folder appearing out of nowhere is exactly the silent magic this plugin does not do.
##
## THE PATH WEARS BRACKETS because it is an EXPRESSION and `.get_base_dir()` binds to the last operand
## of one: `"user://runs/" + slot + ".txt"` would make the folder of `".txt"`, which is nothing at all.
static func make_folder_prelude(path_expression: String) -> String:
	return "DirAccess.make_dir_recursive_absolute((%s).get_base_dir())" % path_expression.strip_edges()


## True when this path names a folder below its scheme, which is the only case where the prelude is
## worth offering. `"user://save.dat"` needs nothing; `"user://runs/latest/save.dat"` needs two
## folders that do not exist yet.
static func has_folders(path_expression: String) -> bool:
	var literal: String = literal_of(path_expression)
	if literal.is_empty():
		return false
	for scheme: String in [USER_SCHEME, RES_SCHEME]:
		if literal.begins_with(scheme):
			return literal.substr(scheme.length()).contains("/")
	return literal.contains("/")


## Whether this verb writes. Asked by the export-trap check, which is silent about reads on purpose:
## reading res:// is what res:// is FOR.
static func writes(ace_id: String) -> bool:
	return WRITE_SHAPED.has(ace_id)


## The parameters of one verb that carry a path, in declaration order. Empty for a verb that has
## none, which is how a caller walks every row of a sheet without a table of its own.
##
## DERIVED FROM THE VERB ITSELF, by the same `file_path` hint the field lead and the files band read.
## A hand-kept list of every path field in the vocabulary is a list that drifts from the vocabulary -
## it did, in the very pass that wrote both halves, and nine path fields including two writes went
## unreachable by the Doctor's fixes while looking like they worked. The table above answers only
## when the registry has nothing to say about this id.
static func path_params_of(ace_id: String, provider_id: String = "Core") -> PackedStringArray:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor != null:
		var found: PackedStringArray = PackedStringArray()
		for entry: Variant in descriptor.params:
			var param: ACEParam = entry as ACEParam
			if param != null and str(param.hint) == PATH_HINT:
				found.append(str(param.id))
		if not found.is_empty():
			return found
	return PackedStringArray(PATH_PARAMS.get(ace_id, []))


## The parameters of one verb that carry a path it WRITES to.
static func write_params_of(ace_id: String) -> PackedStringArray:
	return PackedStringArray(WRITE_SHAPED.get(ace_id, []))


## The read one line IS, taken back apart - the exact inverse of `guarded_read` above, and here
## rather than anywhere else for the reason that function is here: one file spells the guarded shape,
## in both directions, so the verb that writes it and the reading that words it can never disagree
## about what a guard looks like.
##
## Answers `{"path": ..., "fallback": ...}` for a guarded read, `{"path": ..., "fallback": ""}` for a
## plain one, and `{}` for everything else. A blank fallback IS the plain read - the same answer the
## verb gives when its second parameter is left empty.
##
## BOTH PATHS HAVE TO BE THE SAME PATH. A line that reads one file after asking about another is not
## a guarded read: it is the mistake the Doctor reports, and wording it as a working guard is exactly
## how a reader would stop seeing it. So the two are compared and an unequal pair is claimed by
## nothing.
static func read_parts(expression: String) -> Dictionary:
	var text: String = expression.strip_edges()
	if not text.contains(READ_CALL):
		return {}
	if text.begins_with("(") and _closing_paren(text, 0) == text.length() - 1:
		text = text.substr(1, text.length() - 2).strip_edges()
	if not text.begins_with(READ_CALL):
		return {}
	var read_ends: int = _closing_paren(text, READ_CALL.length() - 1)
	if read_ends < 0:
		return {}
	var path: String = text.substr(READ_CALL.length(), read_ends - READ_CALL.length()).strip_edges()
	if path.is_empty():
		return {}
	var rest: String = text.substr(read_ends + 1).strip_edges()
	if rest.is_empty():
		return {"path": path, "fallback": ""}
	var guard_head: String = "if %s" % EXISTS_CALL
	if not rest.begins_with(guard_head):
		return {}
	var exists_ends: int = _closing_paren(rest, guard_head.length() - 1)
	if exists_ends < 0:
		return {}
	var guarded_path: String = rest.substr(guard_head.length(),
		exists_ends - guard_head.length()).strip_edges()
	if guarded_path != path:
		return {}
	var tail: String = rest.substr(exists_ends + 1).strip_edges()
	if not tail.begins_with("else "):
		return {}
	var fallback: String = tail.substr("else ".length()).strip_edges()
	return {} if fallback.is_empty() else {"path": path, "fallback": fallback}


## The index of the bracket that closes the one at `open_index`, or -1 when nothing does. Quoted text
## is stepped over whole, because a bracket inside a string is a character and not a bracket.
static func _closing_paren(text: String, open_index: int) -> int:
	if open_index < 0 or open_index >= text.length() or text.substr(open_index, 1) != "(":
		return -1
	var depth: int = 0
	var quote: String = ""
	var index: int = open_index
	while index < text.length():
		var character: String = text.substr(index, 1)
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## The whole paragraph a path field's help strip shows: both places and what each of them allows,
## then where user:// really is on the machine the game is played on. Composed from the three
## sentences above rather than written out a second time, so the strip and the field's own muted lead
## can never say different things about the same place - and so the strip is translated, those three
## being the wordings the locale files carry.
static func strip_paragraph() -> String:
	return " ".join([lead_for(PLACE_USER), lead_for(PLACE_RES), where_user_lives()])
