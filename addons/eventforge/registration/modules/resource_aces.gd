# EventForge module - Data assets: a folder of .tres as vocabulary, independent copies, pouring
# values between objects, and migrating a record written by an older build.
#
# Four gaps this closes, all of them things a sheet could only reach through a GDScript block:
#
#   1. A FOLDER as content. List Files (file_aces.gd) hands back names and Load Resource
#      (helper_aces.gd) errors loudly on a missing path; nothing composed them. Resources In
#      Folder / Resource In Folder / Load Resource Or Default / Count Of Resources In turn
#      "content lives in files" into vocabulary - item and enemy definitions, level manifests,
#      card sets, a mod folder the player dropped things into. The folder walks trim a trailing
#      ".remap" before testing the extension, because an exported project stores a converted
#      res:// text resource as "<name>.tres.remap" and a naive extension test finds nothing
#      there while working perfectly in the editor. Both folder walks also test the directory
#      first: DirAccess.get_files_at prints a red engine error for a folder that is not there,
#      and "the mod folder does not exist yet" is the normal case, not a fault.
#
#   2. Godot's most expensive beginner trap, made fixable. A .tres dropped on ten nodes is ONE
#      object: writing to it at runtime edits the asset all ten see, and in a @tool sheet it
#      writes back to disk. Copy Resource (Independent) is duplicate(true) - sub-resources and
#      array fields copied too - and Copy Resource (Share Sub-Resources) is the cheap
#      duplicate(false) that deliberately keeps sharing them. Deep Copy is the same distinction
#      for the shipped (shallow) Copy Array / Copy Dictionary. The DETECTION half needs nothing
#      here: Is The Same Object (comparison_aces.gd, "Compare: Objects") already answers "are
#      these two actually one object", and pointing it at two resources is the whole check.
#
#   3. Pouring values from one object into another WITHOUT cloning it. Set Property does one
#      property per row, so a six-property mirror is six rows; Duplicate Node clones wholesale
#      but cannot write onto an existing node. Copy Values From, Fill Blanks From, Apply Preset
#      To Node and Matches Properties Of cover ghost/replay doubles, mirror bosses, paper-doll
#      equipping, difficulty tiers, boss phases, and resetting a pooled node to its template.
#      All four address fields BY NAME. The three POURING verbs skip a name the receiving side does
#      not have, which is what lets one preset serve several node types; the COMPARISON is the other
#      way round on purpose - a name the object under test does not have reads as NOT matching, so a
#      misspelled or renamed field shows up instead of quietly reporting "still in sync".
#
#   4. Data that outlives the shape it was written in. Data Is Older Than Version gates a
#      migration (a record with NO version field - or one holding null, or a word - counts as 0, so
#      the very first format upgrades too), Rename Field moves a value to its new name and is safe
#      to run twice, and Stamp Data Version writes the new number back. Same three serve a save
#      file, a downloaded payload, a mod manifest, a config, and a .tres saved by last month's
#      build. The read side is deliberately str().to_int() and the write side a plain subscript:
#      the first cannot fault on a null, and the second must not out-rank Set Key in the
#      reverse-lifter (see the comment at Stamp Data Version).
#
# Every template is plain, dependency-free GDScript (parity covenant) and null-safe where the
# runtime can hand back nothing: ResourceLoader.exists guards each load, and the copy verbs
# return null rather than calling a method on a non-resource.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant);
# this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeResourceACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_FILES := "Files"
const CAT_HELPERS := "Helpers"
const CAT_ARRAY := "Variables: Array"
const CAT_DICT := "Variables: Dictionary"

## Copies a named list of values from one object onto another, addressed by name so a field the
## target does not have is skipped rather than erroring. A blank name list falls back to every
## variable the SOURCE's script declares (PROPERTY_USAGE_SCRIPT_VARIABLE), which is what makes one
## preset serve several node types.
const _COPY_VALUES_TEMPLATE := "var __src_{uid}: Object = {source}\nvar __dst_{uid}: Object = {target}\nvar __fields_{uid}: PackedStringArray = {names}.split(\",\", false)\nif __fields_{uid}.is_empty():\n\tfor __info_{uid}: Dictionary in __src_{uid}.get_property_list():\n\t\tif int(__info_{uid}[\"usage\"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:\n\t\t\t__fields_{uid}.append(str(__info_{uid}[\"name\"]))\nfor __field_{uid}: String in __fields_{uid}:\n\tvar __key_{uid}: StringName = StringName(__field_{uid}.strip_edges())\n\tif __key_{uid} in __src_{uid} and __key_{uid} in __dst_{uid}:\n\t\t__dst_{uid}.set(__key_{uid}, __src_{uid}.get(__key_{uid}))"

## Writes a base's values ONLY into fields the target left empty (null, or an empty String / Array /
## Dictionary). The override chain: base item plus rarity variant, shipped table plus mod file.
const _FILL_BLANKS_TEMPLATE := "var __base_{uid}: Object = {base}\nvar __target_{uid}: Object = {target}\nfor __info_{uid}: Dictionary in __base_{uid}.get_property_list():\n\tif not (int(__info_{uid}[\"usage\"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):\n\t\tcontinue\n\tvar __field_{uid}: String = str(__info_{uid}[\"name\"])\n\tif not (__field_{uid} in __target_{uid}):\n\t\tcontinue\n\tvar __value_{uid}: Variant = __target_{uid}.get(__field_{uid})\n\tif __value_{uid} == null or (__value_{uid} is String and __value_{uid}.is_empty()) or (__value_{uid} is Array and __value_{uid}.is_empty()) or (__value_{uid} is Dictionary and __value_{uid}.is_empty()):\n\t\t__target_{uid}.set(__field_{uid}, __base_{uid}.get(__field_{uid}))"

## Pours a resource's script variables onto the same-named properties of a node, with both sides
## null-guarded (a preset slot that was never filled in the Inspector is the common case).
const _APPLY_PRESET_TEMPLATE := "var __preset_{uid}: Object = {preset}\nvar __node_{uid}: Object = {target}\nif __preset_{uid} != null and __node_{uid} != null:\n\tfor __info_{uid}: Dictionary in __preset_{uid}.get_property_list():\n\t\tif not (int(__info_{uid}[\"usage\"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):\n\t\t\tcontinue\n\t\tvar __field_{uid}: String = str(__info_{uid}[\"name\"])\n\t\tif __field_{uid} in __node_{uid}:\n\t\t\t__node_{uid}.set(__field_{uid}, __preset_{uid}.get(__field_{uid}))"

## Moves a value to a new field name, leaving the record alone when the old name is not there - the
## single migration step, safe to run twice.
const _RENAME_FIELD_TEMPLATE := "if {record}.has({from_field}):\n\t{record}[{to_field}] = {record}[{from_field}]\n\t{record}.erase({from_field})"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Files - a folder of data assets as vocabulary ──
	# Trailing ".remap" is trimmed BEFORE the extension test: an exported project stores a converted
	# res:// text resource as "<name>.tres.remap", and load() still resolves the original path.
	# The trailing null filter is the same one For Each Resource In Folder ends with, and the two must
	# agree: a mod folder holding a .tres saved by an older build (or one whose script class was
	# removed) loads as null, and a null entry in a list the help calls "your content" is a dead item
	# the first `entry.field` in a For Each trips over - while `listed.has(null)` does NOT reliably
	# catch it, so the guard an author would reach for does not save them either.
	descriptors.append(F.make_descriptor("Core", "ResourcesInFolder", "Resources In Folder", ACEDescriptor.ACEType.EXPRESSION, "Array(DirAccess.get_files_at({folder}) if DirAccess.dir_exists_absolute({folder}) else PackedStringArray()).map(func(__f): return {folder}.path_join(__f.trim_suffix(\".remap\"))).filter(func(__p): return __p.get_extension() in [\"tres\", \"res\"]).map(func(__p): return load(__p)).filter(func(__resource): return __resource != null)", "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder to scan (not recursive). Every .tres / .res inside it is loaded, in the folder's own order.", "expression")], CAT_FILES, "resources in [b]{folder}[/b]")
		.described("Loads every data asset (.tres) in a folder as a list, so a folder of files becomes your content - items, enemies, levels, or a mod folder. A missing folder gives an empty list, and a file that fails to load is left out rather than arriving as nothing."))
	descriptors.append(F.make_descriptor("Core", "ResourceInFolder", "Resource In Folder", ACEDescriptor.ACEType.EXPRESSION, "(load({folder}.path_join({name}) + \".tres\") if ResourceLoader.exists({folder}.path_join({name}) + \".tres\") else null)", "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder holding the data assets.", "expression"), F.make_param("name", "String", "\"item\"", "Name", "File name WITHOUT the .tres extension - \"rusty_sword\" finds rusty_sword.tres.", "expression")], CAT_FILES, "resource [b]{name}[/b] in [b]{folder}[/b]")
		.described("Fetches one data asset out of a folder by its file name, or nothing at all when there is no such file - no red error."))
	descriptors.append(F.make_descriptor("Core", "LoadResourceOrDefault", "Load Resource Or Default", ACEDescriptor.ACEType.EXPRESSION, "(load({path}) if ResourceLoader.exists({path}) else {fallback})", "", [F.make_param("path", "String", "\"res://data/item.tres\"", "Path", "Full path to the resource or scene to load.", "expression"), F.make_param("fallback", "String", "null", "Fallback", "What to use instead when the file is not there (a preloaded default, or null).", "expression")], CAT_FILES, "load [b]{path}[/b] or [i]{fallback}[/i]")
		.described("Loads a file and hands back your fallback when it is missing, so a deleted or mod-supplied file never crashes the game."))
	# ── V4. The two plainest data-asset steps, in the shape a hand-written file writes them ──
	# Deliberately NOT guarded: these two write the exact `load(path)` / `ResourceSaver.save(r, path)`
	# a script writes by hand, so a picked row and a typed line are the same bytes and read the same
	# sentence. Load Resource Or Default beside them is the forgiving version for content that may
	# be missing.
	descriptors.append(F.make_descriptor("Core", "DataAsset", "Data Asset", ACEDescriptor.ACEType.EXPRESSION, "load({path})", "", [F.make_param("path", "String", "\"res://data/item.tres\"", "File", "The .tres to fetch.", "expression")], CAT_FILES, "the data asset [b]{path}[/b]")
		.described("Fetches one data asset by its path - the values a designer filled in the Inspector, ready to read fields off.").featured())
	descriptors.append(F.make_descriptor("Core", "SaveDataAsset", "Save Data Asset", ACEDescriptor.ACEType.ACTION, "ResourceSaver.save({resource}, {path})", "", [F.make_param("resource", "String", "null", "Asset", "The data asset to write out.", "expression"), F.make_param("path", "String", "\"res://data/item.tres\"", "As", "Where to write it. Writing under res:// only works in the editor; a running game writes to user://.", "expression")], CAT_FILES, "Save data asset [b]{resource}[/b] as [b]{path}[/b]")
		.described("Writes a data asset back to a file. An editor tool uses this to generate or bulk-edit content; a running game should write under user://."))
	descriptors.append(F.make_descriptor("Core", "CountResourcesInFolder", "Count Of Resources In", ACEDescriptor.ACEType.EXPRESSION, "Array(DirAccess.get_files_at({folder}) if DirAccess.dir_exists_absolute({folder}) else PackedStringArray()).filter(func(__f): return __f.trim_suffix(\".remap\").get_extension() in [\"tres\", \"res\"]).size()", "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder to count data assets in (not recursive).", "expression")], CAT_FILES, "count of resources in [b]{folder}[/b]")
		.described("How many data assets a folder holds, counted without loading any of them - zero if the folder is missing."))

	# ── Helpers - independent copies (the shared-.tres trap) ──
	# duplicate(true) copies sub-resources AND array/dictionary fields; duplicate(false) shares them.
	# Naming both halves is the point: the trap bites precisely because no shipped verb said which
	# copy you were getting. The "are these one object" half is Is The Same Object (Compare: Objects).
	descriptors.append(F.make_descriptor("Core", "CopyResourceDeep", "Copy Resource (Independent)", ACEDescriptor.ACEType.EXPRESSION, "({resource}.duplicate(true) if {resource} is Resource else null)", "", [F.make_param("resource", "String", "Resource.new()", "Resource", "The resource to copy. Anything that is not a resource (including nothing at all) gives nothing back.", "expression")], CAT_HELPERS, "independent copy of [i]{resource}[/i]")
		.described("Makes a private copy of a resource, right down to the resources inside it, so writing to the copy never changes the .tres on disk or any other node holding it. Use this before a node edits its own stats."))
	descriptors.append(F.make_descriptor("Core", "CopyResourceShallow", "Copy Resource (Share Sub-Resources)", ACEDescriptor.ACEType.EXPRESSION, "({resource}.duplicate(false) if {resource} is Resource else null)", "", [F.make_param("resource", "String", "Resource.new()", "Resource", "The resource to copy. Anything that is not a resource (including nothing at all) gives nothing back.", "expression")], CAT_HELPERS, "copy of [i]{resource}[/i] (sub-resources shared)")
		.described("Makes a cheap copy whose own fields are separate but whose inner resources and lists are still SHARED with the original. Pick this only when you want that sharing - otherwise use Copy Resource (Independent)."))
	descriptors.append(F.make_descriptor("Core", "ArrayDeepDuplicate", "Deep Copy", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.duplicate(true)", "", [F.make_param("var_name", "String", "list", "Array", "Array variable to copy right through.", "variable_reference:Array")], CAT_ARRAY, "deep copy of [b]{var_name}[/b]")
		.described("Copies the array AND every list or dictionary nested inside it, so editing the copy cannot reach back into the original. Copy Array only copies the outer level."))
	descriptors.append(F.make_descriptor("Core", "DictDeepDuplicate", "Deep Copy", ACEDescriptor.ACEType.EXPRESSION, "{var_name}.duplicate(true)", "", [F.make_param("var_name", "String", "dict", "Dictionary", "Dictionary variable to copy right through.", "variable_reference:Dictionary")], CAT_DICT, "deep copy of [b]{var_name}[/b]")
		.described("Copies the dictionary AND every list or dictionary nested inside it, so editing the copy cannot reach back into the original. Copy Dictionary only copies the outer level."))

	# ── Helpers - pouring values between objects (no cloning, no six-row mirror) ──
	descriptors.append(F.make_descriptor("Core", "CopyValuesFrom", "Copy Values From", ACEDescriptor.ACEType.ACTION, _COPY_VALUES_TEMPLATE, "", [F.make_param("target", "String", "self", "Into", "The object being written to - it is what changes.", "expression"), F.make_param("source", "String", "self", "From", "The object to read from - a node OR a resource.", "expression"), F.make_param("names", "String", "\"\"", "Names", "Comma-separated property names. Leave blank to copy every variable the source's script declares.", "expression")], CAT_HELPERS, "copy [b]{names}[/b] from [i]{source}[/i] into [i]{target}[/i]")
		.described("Pours a list of values off another object onto this one, in one row instead of one row per property. Names the target does not have are skipped, so a single preset can serve several kinds of node."))
	descriptors.append(F.make_descriptor("Core", "FillBlanksFrom", "Fill Blanks From", ACEDescriptor.ACEType.ACTION, _FILL_BLANKS_TEMPLATE, "", [F.make_param("target", "String", "self", "Fill", "The one being completed - it is what changes.", "expression"), F.make_param("base", "String", "self", "From", "Where the missing values come from.", "expression")], CAT_HELPERS, "fill blanks in [i]{target}[/i] from [i]{base}[/i]")
		.described("Writes a base's values ONLY into fields this object left empty, leaving everything you did fill in alone. That is the override chain: a base item plus a rarity variant, or a shipped table plus a mod file. Empty means nothing there: no value at all, blank text, an empty list or an empty record - a 0 and a false are real values and are kept, exactly as Is Nothing and Missing Fields read them."))
	descriptors.append(F.make_descriptor("Core", "ApplyPresetToNode", "Apply Preset To Node", ACEDescriptor.ACEType.ACTION, _APPLY_PRESET_TEMPLATE, "", [F.make_param("preset", "String", "null", "Preset", "The data asset to pour on (a .tres you filled in the Inspector). Nothing happens if it is empty.", "expression"), F.make_param("target", "String", "self", "To", "The node to apply it to.", "expression")], CAT_HELPERS, "apply preset [b]{preset}[/b] to [i]{target}[/i]")
		.described("Pours a data asset's fields onto the same-named properties of a node, so difficulty tiers, weapon tunings and boss phases become a data edit instead of a wall of rows."))
	# `__n in {target}` is not belt-and-braces: Object.get() answers null for a property that is not
	# there, so WITHOUT it a misspelled or renamed name compared null to null and the row reported
	# "still in sync" - the safest-looking answer, and the wrong one. Requiring the name to exist on
	# the object under test turns a typo into a plain false instead. Both sides are null-guarded too,
	# because "the ghost was freed" is exactly when this condition gets asked.
	descriptors.append(F.make_descriptor("Core", "MatchesPropertiesOf", "Matches Properties Of", ACEDescriptor.ACEType.CONDITION, "({target} != null and {other} != null and Array({names}.split(\",\", false)).all(func(__n): return __n.strip_edges() in {target} and {target}.get(__n.strip_edges()) == {other}.get(__n.strip_edges())))", "", [F.make_param("target", "String", "self", "Object", "The object to test.", "expression"), F.make_param("names", "String", "\"position, rotation\"", "Names", "Comma-separated property names to compare. A blank list has nothing to compare, so it is true.", "expression"), F.make_param("other", "String", "self", "Of", "The object to compare against.", "expression")], CAT_HELPERS, "[i]{target}[/i] matches [b]{names}[/b] of [i]{other}[/i]")
		.described("True while the listed properties hold the same values on both objects - the cheap 'is this ghost still in sync' or 'has anything changed' check. A name neither object has reads as NOT matching, so a typo shows up instead of quietly passing, and either side being gone reads as not matching too."))

	# ── Variables: Dictionary - migrating a record written by an older build ──
	# `str(…).to_int()` rather than `int(…)`: Dictionary.get falls back only on a MISSING key, so a
	# payload carrying `"version": null` (a field written but never filled) reached int(null), which
	# is a runtime error - and taking down the gate that exists to make old data safe is the one
	# failure this verb must not have. to_int reads "3" and 3 and 3.0 alike and answers 0 for null,
	# for a word, and for anything else that is not a number, which is exactly "count it as oldest".
	descriptors.append(F.make_descriptor("Core", "DataIsOlderThanVersion", "Data Is Older Than Version", ACEDescriptor.ACEType.CONDITION, "(str({record}.get({field}, 0)).to_int() < {version})", "", [F.make_param("record", "String", "save", "Record", "The parsed record (a save file, a payload, a manifest).", "variable_reference:Dictionary"), F.make_param("field", "String", "\"version\"", "Field", "Which field holds the version number.", "expression"), F.make_param("version", "String", "2", "Version", "The version this build writes.", "expression")], CAT_DICT, "[b]{record}[/b] is older than version [b]{version}[/b]")
		.described("True when a loaded record was written by an older build than this one - the gate a migration sits under. A record with NO version field counts as 0, so the very first format upgrades too, and so does one whose version field is empty or is not a number at all."))
	descriptors.append(F.make_descriptor("Core", "RenameField", "Rename Field", ACEDescriptor.ACEType.ACTION, _RENAME_FIELD_TEMPLATE, "", [F.make_param("record", "String", "save", "Record", "The record to migrate, edited in place.", "variable_reference:Dictionary"), F.make_param("from_field", "String", "\"hp\"", "From", "The old field name.", "expression"), F.make_param("to_field", "String", "\"health\"", "To", "The new field name (overwritten if it is already there).", "expression")], CAT_DICT, "rename [b]{from_field}[/b] to [b]{to_field}[/b] in [i]{record}[/i]")
		.described("Moves a value to its new field name, and does nothing at all when the old name is not there - so a migration is safe to run twice."))
	# The emitted line is a PLAIN subscript write, deliberately - an earlier draft wrapped the number
	# in int(), and `{record}[{field}] = int({version})` carries more literal characters than Set
	# Key's `{var_name}[{key}] = {value}`, which is what the reverse-lifter sorts on. That made this
	# verb out-rank Set Key and re-label every hand-written `config["count"] = int(text_value)` in a
	# user's project as "stamp this record as version text_value". Ties with Set Key now, and Set Key
	# is authored earlier, so ordinary code keeps lifting as ordinary code; the price is that a
	# stamped row itself reads back as Set Key on reopen, which is a true reading of what it emits.
	descriptors.append(F.make_descriptor("Core", "StampDataVersion", "Stamp Data Version", ACEDescriptor.ACEType.ACTION, "{record}[{field}] = {version}", "", [F.make_param("record", "String", "save", "Record", "The record to stamp.", "variable_reference:Dictionary"), F.make_param("field", "String", "\"version\"", "Field", "Which field holds the version number.", "expression"), F.make_param("version", "String", "2", "Version", "The version this build writes - a whole number.", "expression")], CAT_DICT, "stamp [i]{record}[/i] as version [b]{version}[/b]")
		.described("Writes the current format number onto a record, so the next load knows it has already been migrated. Data Is Older Than Version reads it back, and reads it as 0 when it is missing or is not a number."))

	# ── Live Data - data that changed on disk while the game is running, and a folder that is wrong ──
	#
	# Two halves of the balance-tuning loop, both plain GDScript:
	#
	#   Watch Data File compares the file's modification time with the one it saw last, remembered in
	#   host metadata under the path (the stateless, name-keyed trick the cooldowns use - an ACTION
	#   cannot declare a class member). The FIRST run only seeds the stamp, so nothing fires just
	#   because the row started running. When the stamp moves, the change is handed on as a real
	#   signal: declare `signal data_file_changed(path: String)` on the sheet (Add ▸ Signal) and the
	#   On Signal trigger row receives the path as its own captured payload - never a "which file
	#   changed" side expression, which is wrong the moment two files land in the same poll. A sheet
	#   that declares no such signal skips the emit, so the row still stands alone.
	#
	#   The folder report is one expression by necessity (an expression lands in a value field), and
	#   the SAME text backs the condition, the reading and the warning, so the three can never
	#   disagree. It answers the three things that silently break a folder of data assets: a file
	#   that no longer loads, one with no usable id, and two files claiming the same id - where the
	#   second silently wins every lookup. An empty report means the folder is clean, the same
	#   convention Explain Table Problem and Missing Fields use.
	var data_rows: String = "Array(DirAccess.get_files_at({folder}) if DirAccess.dir_exists_absolute({folder}) else PackedStringArray()).map(func(__file): return {folder}.path_join(__file.trim_suffix(\".remap\"))).filter(func(__path): return __path.get_extension() in [\"tres\", \"res\"]).map(func(__path): return [__path.get_file(), load(__path)])"
	# Each file is loaded ONCE, into a [file name, resource] pair, and the whole report is built from
	# those pairs inside one immediately-called lambda. The obvious spelling - load(__path) wherever a
	# question needs it, and the id list rebuilt per file for the duplicate check - re-read every asset
	# several times per file, so a 200-asset folder cost tens of thousands of loads on every evaluation
	# of what is, after all, a CONDITION a row may ask once a frame.
	var folder_problems: String = "(func(__rows: Array) -> String: return \"\\n\".join(PackedStringArray(__rows.map(func(__row): return (str(__row[0]) + \": cannot be loaded\" if __row[1] == null else (str(__row[0]) + \": has no id\" if not (\"id\" in __row[1]) or str(__row[1].get(\"id\")).strip_edges().is_empty() else (str(__row[0]) + \": shares its id with another file\" if __rows.filter(func(__other): return __other[1] != null and \"id\" in __other[1] and str(__other[1].get(\"id\")) == str(__row[1].get(\"id\"))).size() > 1 else \"\")))).filter(func(__message): return not __message.is_empty())))).call(%s)" % data_rows

	descriptors.append(F.make_descriptor("Core", "WatchDataFile", "Watch Data File", ACEDescriptor.ACEType.ACTION, "var __stamp_{uid}: int = FileAccess.get_modified_time({path}) if FileAccess.file_exists({path}) else 0\nif __stamp_{uid} != int(get_meta(&\"__ef_watch_\" + str({path}).to_utf8_buffer().hex_encode(), __stamp_{uid})):\n\tif has_signal(&\"data_file_changed\"):\n\t\temit_signal(&\"data_file_changed\", {path})\nset_meta(&\"__ef_watch_\" + str({path}).to_utf8_buffer().hex_encode(), __stamp_{uid})", "", [F.make_param("path", "String", "\"res://data/items/sword.tres\"", "File", "The data file to watch (a .tres, .json or .csv).", "expression")], CAT_FILES, "watch [b]{path}[/b] for edits")
		.described("Checks whether a data file has been written since the last check, and fires the sheet's data_file_changed(path) signal when it has - so you edit an enemy's numbers in the Inspector and the running game picks them up. Put it under Every X Seconds; the first check only takes a reading, so nothing fires just because the row started. This is a debug-build tool: it reads the file's timestamp each time it runs."))
	descriptors.append(F.make_descriptor("Core", "ReloadDataAsset", "Reload Data Asset", ACEDescriptor.ACEType.ACTION, "if ResourceLoader.exists({path}):\n\tResourceLoader.load({path}, \"\", ResourceLoader.CACHE_MODE_REPLACE)", "", [F.make_param("path", "String", "\"res://data/items/sword.tres\"", "File", "The data asset to re-read from disk.", "expression")], CAT_FILES, "reload data asset [b]{path}[/b]")
		.described("Re-reads a data asset from disk into the copy every node is already holding, so the new numbers apply without restarting or re-assigning anything. It reloads DATA, not code: a changed script still needs a restart. Nothing happens when the path is not there."))
	# The trigger half. "signal:<name>" is the id convention that binds a row to a real signal: the
	# sheet declares `data_file_changed(path: String)` with a Signal row, and the compiler emits the
	# handler plus its _ready connection. The path arrives as the row's OWN captured payload, which
	# is the whole reason no "which file changed" expression exists - watching a folder is exactly
	# the case where two files land in the same check, and a stored last-value would be wrong.
	descriptors.append(F.make_descriptor("Core", "signal:data_file_changed", "On Data File Changed", ACEDescriptor.ACEType.TRIGGER, "", "data_file_changed", [F.make_param("path", "String", "", "File", "The file that was written, carried by the signal itself.")], CAT_FILES, "On data file changed ( {path} )")
		.described("Runs when a Watch Data File row notices that a watched file has been written. The path arrives on the row as path, so the reaction reloads exactly the file that changed even when two land in the same check. Needs a Signal row for data_file_changed(path: String) - without one the sheet still compiles, but nothing connects this event, so it never runs. The Project Doctor flags that."))
	descriptors.append(F.make_descriptor("Core", "DataFolderProblems", "Data Folder Problems", ACEDescriptor.ACEType.EXPRESSION, folder_problems, "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder of data assets to check (not recursive).", "expression")], CAT_FILES, "problems in [b]{folder}[/b]")
		.described("Every structural problem in a folder of data assets, one per line, and \"\" when it is clean: a file that cannot be loaded, one with no usable id, and two files claiming the same id (where the second quietly wins every lookup). Show it, log it, or fail a build with it."))
	descriptors.append(F.make_descriptor("Core", "DataFolderIsValid", "Data Folder Is Valid", ACEDescriptor.ACEType.CONDITION, "(%s).is_empty()" % folder_problems, "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder of data assets to check (not recursive).", "expression")], CAT_FILES, "[b]{folder}[/b] is valid data")
		.described("True when every data asset in a folder loads, has an id, and has an id no sibling shares - the check to put in front of loading a mod folder or user content. Read the reasons with Data Folder Problems."))
	descriptors.append(F.make_descriptor("Core", "ValidateDataFolder", "Validate Data Folder", ACEDescriptor.ACEType.ACTION, "var __report_{uid}: String = %s\nif not __report_{uid}.is_empty():\n\tpush_warning(\"Data folder \" + {folder} + \" has problems:\\n\" + __report_{uid})" % folder_problems, "", [F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder of data assets to check (not recursive).", "expression")], CAT_FILES, "validate data folder [b]{folder}[/b]")
		.described("Checks a folder of data assets and writes every problem it finds to the Output as one warning, saying which file and what is wrong. A clean folder says nothing at all, so it is safe to leave in a startup event."))

	return descriptors
