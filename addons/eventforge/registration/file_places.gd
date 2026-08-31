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
const WRITE_SHAPED: Dictionary = {
	"WriteTextFile": ["path"],
	"AppendTextFile": ["path"],
	"WriteTextFileInFolder": ["path"],
	"DeleteFile": ["path"],
	"MoveFile": ["to"],
	"CopyFile": ["to"],
	"MakeDir": ["path"],
	"RemoveDir": ["path"],
}

## Every file verb's path parameters, write-shaped or not. The absolute-path check reads this one:
## an absolute path is wrong in a read as well as in a write, because the folder it names is on
## exactly one computer.
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
static func guarded_read(path_expression: String, fallback_expression: String) -> String:
	var path: String = path_expression.strip_edges()
	var fallback: String = fallback_expression.strip_edges()
	if fallback.is_empty():
		return "FileAccess.get_file_as_string(%s)" % path
	return "FileAccess.get_file_as_string(%s) if FileAccess.file_exists(%s) else %s" % [
		path, path, fallback]


## The prelude a write asks for when its path has folders in it: the one line that makes them, which
## Godot will not do on the way to opening a file. Emitted ABOVE the write and shown in the row's own
## echo - a folder appearing out of nowhere is exactly the silent magic this plugin does not do.
static func make_folder_prelude(path_expression: String) -> String:
	return "DirAccess.make_dir_recursive_absolute(%s.get_base_dir())" % path_expression.strip_edges()


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
static func path_params_of(ace_id: String) -> PackedStringArray:
	return PackedStringArray(PATH_PARAMS.get(ace_id, []))


## The parameters of one verb that carry a path it WRITES to.
static func write_params_of(ace_id: String) -> PackedStringArray:
	return PackedStringArray(WRITE_SHAPED.get(ace_id, []))
