# EventForge - a group's `## @ace_group(...)` header line in a script that is its own sheet.
#
# A sheet-native compile writes every group's header from the group itself. A script that IS the
# sheet (a `.gd` opened in the editor) keeps its header lines verbatim instead, inside the rows the
# file opened with, so an untouched file saves byte for byte. That left the lines stale the moment a
# group changed: a new colour, a rename, "Can Be Switched At Runtime" - none of it reached the file,
# and switching a group on emitted `if __group_x_active:` with no `var __group_x_active` to read.
#
# keep_in_step() is the one pass that settles both after the rows have been written:
#
#     ## @ace_group(uid="wave", name="Wave", toggleable=true)   <- rewritten only when the group changed
#     ...
#     var __group_wave_active: bool = true                      <- added, renamed, re-defaulted, removed
#
# A header line is compared by what it READS as, never by its spelling: the line is read back into a
# group exactly the way opening the file reads it, and only when that group would write a different
# line than the live one does the live one's line replace it. So every untouched header - including
# one spelled by hand - stays exactly as it was written.
#
# Which line belongs to which group: the uid the lift read it from (SheetCompiler.SOURCE_GROUP_SLUG_META
# on the group), else the uid the group would be written with now. A header whose group was opened
# and has since been deleted is removed (the uids that were opened are SOURCE_GROUP_SLUGS_META on the
# sheet); one that never belonged to an opened group (an empty group, say) is left alone.
#
# The flag member follows the groups whose header changed: renamed with its group, its starting value
# rewritten with Active On Start, removed when the group can no longer be switched. Any flag the
# emitted code reads and no line declares is added - without it the saved script would not parse.
# DELIBERATELY NO `class_name`: the compiler and the lift reach it with a const preload.
@tool
extends RefCounted

const HEADER_PREFIX: String = "## @ace_group("


## The fields of one header line, `{uid, name, parent?, description?, color?, collapsed?, toggleable?,
## enabled?, runs_on?, runs_in?}` - quoted values as Strings, bare true/false as bools. {} when the line
## is not a group header at all.
static func parse_line(line: String) -> Dictionary:
	if not line.begins_with(HEADER_PREFIX):
		return {}
	var header_regex: RegEx = RegEx.new()
	if header_regex.compile("^## @ace_group\\((.*)\\)\\s*$") != OK:
		return {}
	var header_match: RegExMatch = header_regex.search(line)
	if header_match == null:
		return {}
	return parse_fields(header_match.get_string(1))


## A header's field list (`uid="x", name="y", collapsed=true`) as a typed dictionary. Tolerant of
## order and of missing optional fields.
static func parse_fields(inner: String) -> Dictionary:
	var fields: Dictionary = {}
	var field_regex: RegEx = RegEx.new()
	if field_regex.compile("([a-z_]+)=(\"[^\"]*\"|true|false)") != OK:
		return fields
	for field_match: RegExMatch in field_regex.search_all(inner):
		var key: String = field_match.get_string(1)
		var raw: String = field_match.get_string(2)
		if raw == "true":
			fields[key] = true
		elif raw == "false":
			fields[key] = false
		else:
			fields[key] = raw.substr(1, raw.length() - 2)
	return fields


## The group a header line reads as - the one place that answer is written, so opening a file and
## asking whether a header still says what its group says can never read a field two ways.
static func group_from_fields(fields: Dictionary) -> EventGroup:
	var slug: String = str(fields.get("uid", ""))
	var group: EventGroup = EventGroup.new()
	group.group_name = str(fields.get("name", slug))
	group.name = group.group_name
	group.description = str(fields.get("description", ""))
	group.read_header_color(str(fields.get("color", "")))
	group.collapsed = bool(fields.get("collapsed", false))
	group.expanded = not group.collapsed
	group.runtime_toggleable = bool(fields.get("toggleable", false))
	group.enabled = bool(fields.get("enabled", true))
	group.runs_on = str(fields.get("runs_on", ""))
	group.runs_in = str(fields.get("runs_in", ""))
	return group


## The runtime flag a group header's group is switched by, or "" when the header says it cannot be
## switched.
static func flag_of_fields(fields: Dictionary) -> String:
	if not bool(fields.get("toggleable", false)):
		return ""
	return flag_name(group_from_fields(fields).group_name)


## The member a switchable group named `group_name` is switched by - the compiler's own spelling.
static func flag_name(group_name: String) -> String:
	return "__group_%s_active" % SheetCompiler.guard_token(group_name)


## The one header line `group` writes under `slug`, nested under `parent_slug`.
static func line_for(group: EventGroup, slug: String, parent_slug: String) -> String:
	var written: PackedStringArray = PackedStringArray()
	SheetCompiler._emit_group_declarations(written, [{"slug": slug, "parent": parent_slug, "group": group}])
	return written[0] if not written.is_empty() else ""


## Brings the header lines and the flag members of an opened script in step with its groups. `decls`
## is the compile's {slug, parent, group} walk (parents first); `flags` its [flag name, on at start]
## pairs - the members the emitted code reads. Returns the lines to write; `source_map` follows them.
static func keep_in_step(lines: PackedStringArray, sheet: EventSheetResource, decls: Array, flags: Array,
		source_map: Array) -> PackedStringArray:
	var declared_at: Dictionary = {}
	var declared_fields: Dictionary = {}
	var last_header: int = -1
	for index: int in range(lines.size()):
		if not lines[index].begins_with(HEADER_PREFIX):
			continue
		var fields: Dictionary = parse_line(lines[index])
		if fields.is_empty():
			continue
		last_header = index
		var uid: String = str(fields.get("uid", ""))
		if not uid.is_empty() and not declared_at.has(uid):
			declared_at[uid] = index
			declared_fields[uid] = fields
	if decls.is_empty() and declared_at.is_empty() and flags.is_empty():
		return lines
	# Which line is whose. The uid the lift read first, so a renamed group keeps its own line; then
	# the uid it would be written with, so a group added since takes over a line nobody else claims.
	var owner_of: Array = []
	var claimed: Dictionary = {}
	for decl: Dictionary in decls:
		var source_slug: String = str((decl["group"] as EventGroup).get_meta(SheetCompiler.SOURCE_GROUP_SLUG_META, ""))
		if not source_slug.is_empty() and declared_at.has(source_slug) and not claimed.has(source_slug):
			claimed[source_slug] = true
			owner_of.append(source_slug)
		else:
			owner_of.append("")
	for decl_index: int in range(decls.size()):
		var slug: String = str((decls[decl_index] as Dictionary)["slug"])
		if str(owner_of[decl_index]).is_empty() and declared_at.has(slug) and not claimed.has(slug):
			claimed[slug] = true
			owner_of[decl_index] = slug
	var replaced: Dictionary = {}
	var removed: Dictionary = {}
	var added: PackedStringArray = PackedStringArray()
	# The flags whose group's header changed: the one it was switched by, and the one it is now.
	var flags_before: Dictionary = {}
	var flags_now: Dictionary = {}
	for decl_index: int in range(decls.size()):
		var decl: Dictionary = decls[decl_index]
		var group: EventGroup = decl["group"] as EventGroup
		var wanted: String = line_for(group, str(decl["slug"]), str(decl["parent"]))
		var uid: String = str(owner_of[decl_index])
		if uid.is_empty():
			added.append(wanted)
		else:
			var fields: Dictionary = declared_fields[uid]
			if line_for(group_from_fields(fields), uid, str(fields.get("parent", ""))) == wanted:
				continue
			replaced[int(declared_at[uid])] = wanted
			var flag_before: String = flag_of_fields(fields)
			if not flag_before.is_empty():
				flags_before[flag_before] = true
		if group.runtime_toggleable:
			flags_now[flag_name(group.group_name)] = true
	var opened: PackedStringArray = sheet.get_meta(SheetCompiler.SOURCE_GROUP_SLUGS_META, PackedStringArray()) \
			if sheet != null else PackedStringArray()
	for uid: String in declared_at:
		if not claimed.has(uid) and opened.has(uid):
			removed[int(declared_at[uid])] = true
			var gone_flag: String = flag_of_fields(declared_fields[uid])
			if not gone_flag.is_empty():
				flags_before[gone_flag] = true
	var inserted: Dictionary = {}
	if not added.is_empty():
		var at: int = last_header if last_header >= 0 else _header_home(lines)
		var block: PackedStringArray = added.duplicate()
		# A header written straight above a member would read as that member's doc comment.
		if last_header < 0 and at + 1 < lines.size() and not lines[at + 1].strip_edges().is_empty():
			block.append("")
		inserted[at] = block
	if not replaced.is_empty() or not removed.is_empty() or not inserted.is_empty():
		lines = _rebuilt(lines, replaced, removed, inserted, source_map)
	return _flags_in_step(lines, flags, flags_before, flags_now, source_map)


## The flag members, in step with the groups: see the header of this file.
static func _flags_in_step(lines: PackedStringArray, flags: Array, flags_before: Dictionary,
		flags_now: Dictionary, source_map: Array) -> PackedStringArray:
	var wanted_on: Dictionary = {}
	for flag: Array in flags:
		wanted_on[str(flag[0])] = bool(flag[1])
	var exact: RegEx = RegEx.new()
	exact.compile("^var (__group_[A-Za-z0-9_]+_active): bool = (true|false)$")
	var any_declaration: RegEx = RegEx.new()
	any_declaration.compile("^(?:@\\S+\\s+)*(?:static\\s+)?var\\s+(__group_[A-Za-z0-9_]+_active)\\b")
	var declared: Dictionary = {}
	var last_flag: int = -1
	var last_header: int = -1
	var first_function: int = -1
	for index: int in range(lines.size()):
		var line: String = lines[index]
		if line.begins_with(HEADER_PREFIX):
			last_header = index
		elif first_function < 0 and (line.begins_with("func ") or line.begins_with("static func ")):
			first_function = index
		if not line.contains("var __group_"):
			continue
		var declaration: RegExMatch = any_declaration.search(line)
		if declaration != null:
			declared[declaration.get_string(1)] = true
		if exact.search(line) != null:
			last_flag = index
	# Flags a changed group now needs and nothing declares: a renamed group's old line becomes these.
	var renames: Array = []
	for flag: Array in flags:
		if flags_now.has(str(flag[0])) and not declared.has(str(flag[0])):
			renames.append(str(flag[0]))
	var replaced: Dictionary = {}
	var removed: Dictionary = {}
	for index: int in range(lines.size()):
		if not lines[index].begins_with("var __group_"):
			continue
		var flag_line: RegExMatch = exact.search(lines[index])
		if flag_line == null:
			continue
		var flag: String = flag_line.get_string(1)
		var on: bool = flag_line.get_string(2) == "true"
		if wanted_on.has(flag):
			if (flags_now.has(flag) or flags_before.has(flag)) and on != bool(wanted_on[flag]):
				replaced[index] = _flag_line(flag, bool(wanted_on[flag]))
		elif flags_before.has(flag):
			if not renames.is_empty():
				var renamed: String = str(renames.pop_front())
				replaced[index] = _flag_line(renamed, bool(wanted_on[renamed]))
				declared[renamed] = true
			else:
				removed[index] = true
	var missing: PackedStringArray = PackedStringArray()
	for flag: Array in flags:
		if not declared.has(str(flag[0])):
			missing.append(_flag_line(str(flag[0]), bool(flag[1])))
	var inserted: Dictionary = {}
	if not missing.is_empty():
		if last_flag >= 0:
			inserted[last_flag] = missing
		elif last_header >= 0:
			inserted[last_header] = PackedStringArray([""]) + missing
		else:
			# No header at all to sit under: just above the first function, or at the end.
			var above: int = (first_function if first_function >= 0 else lines.size()) - 1
			inserted[above] = missing + PackedStringArray([""])
	if replaced.is_empty() and removed.is_empty() and inserted.is_empty():
		return lines
	return _rebuilt(lines, replaced, removed, inserted, source_map)


static func _flag_line(flag: String, on: bool) -> String:
	return "var %s: bool = %s" % [flag, "true" if on else "false"]


## Where the first header goes when the file has none: under the class's opening lines (`extends`,
## `class_name`, the annotations above them) and the `##` doc block `extends` opens, past the blank
## line that closes them. A header straight under `extends` would read as the class's own doc
## comment, and one above `@icon` would put the switch flag where Godot refuses a member.
static func _header_home(lines: PackedStringArray) -> int:
	var at: int = -1
	var index: int = 0
	# The opening lines: annotations, `class_name`, `extends`, and comments between them.
	while index < lines.size():
		var line: String = lines[index]
		if line.begins_with("extends ") or line.begins_with("class_name ") or line.begins_with("@tool") \
				or line.begins_with("@icon(") or line.begins_with("@static_unload") or line.begins_with("@abstract"):
			at = index
		elif not line.strip_edges().is_empty() and not line.begins_with("#"):
			break
		elif at >= 0 and line.strip_edges().is_empty():
			break
		index += 1
	if at < 0:
		return at
	# The class's doc block, when it is one: `##` lines under the opening that end at a blank line
	# or the end of the file (a block running into a member is that member's doc, and stays put).
	var doc_end: int = at
	while doc_end + 1 < lines.size() and lines[doc_end + 1].begins_with("##"):
		doc_end += 1
	if doc_end + 1 >= lines.size() or lines[doc_end + 1].strip_edges().is_empty():
		at = doc_end
	# Past the blank line that closes the opening, so the header stands on its own.
	if at + 1 < lines.size() and lines[at + 1].strip_edges().is_empty():
		at += 1
	return at


## `lines` with each index in `replaced` swapped for its line, each in `removed` dropped and each
## block in `inserted` written after its index (-1 = at the very top). The source map's 1-based
## ranges follow their lines: a dropped line's range shrinks, an insertion pushes the rest down.
static func _rebuilt(lines: PackedStringArray, replaced: Dictionary, removed: Dictionary, inserted: Dictionary,
		source_map: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# new_line_of[i] = the 0-based line old line i became (or would have, when it was dropped).
	var new_line_of: PackedInt32Array = PackedInt32Array()
	new_line_of.resize(lines.size())
	if inserted.has(-1):
		out.append_array(inserted[-1])
	for index: int in range(lines.size()):
		new_line_of[index] = out.size()
		if not removed.has(index):
			out.append(str(replaced.get(index, lines[index])))
		if inserted.has(index):
			out.append_array(inserted[index])
	for entry: Variant in source_map:
		if not (entry is Dictionary):
			continue
		var mapped: Dictionary = entry as Dictionary
		var start: int = int(mapped.get("start", 0))
		var end: int = int(mapped.get("end", 0))
		if start >= 1 and start <= lines.size():
			mapped["start"] = new_line_of[start - 1] + 1
		if end >= 1 and end <= lines.size():
			# The last line of the range that is still there, or the line before where it was.
			var last_kept: int = new_line_of[end - 1] + (0 if not removed.has(end - 1) else -1)
			mapped["end"] = maxi(last_kept + 1, int(mapped["start"]))
	return out
